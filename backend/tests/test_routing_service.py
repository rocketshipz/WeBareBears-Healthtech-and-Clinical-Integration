from datetime import datetime, timedelta, timezone

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import text

from app.main import app
from app.api.routes.auth import get_auth_service
from app.core.config import get_settings
from app.core.database import Base, get_engine, get_session_factory
from app.models.hospital_directory import HospitalDirectory
from app.models.triage_report import SavedReport
from app.models.user import User
from app.repositories.hospital_repository import HospitalActivityRow
from app.schemas.hospital import Coordinates
from app.services.routing_service import RoutingService, rank_hospitals

KL = Coordinates(latitude=3.1390, longitude=101.6869)


def row(hid, lat, lon, activity="low", category="unknown"):
    return HospitalActivityRow(hospital_id=hid, name=hid, category=category, address="", phone=None,
                               latitude=lat, longitude=lon, activity_level=activity)


# NEAR is ~1 km away and very busy; FAR is ~11 km away and quiet.
NEAR = row("NEAR", 3.1480, 101.6869, "very busy")
FAR = row("FAR", 3.2390, 101.6869, "low")


def ids(recs):
    return [r.hospital.hospital_id for r in recs]


def test_level_1_goes_to_nearest_even_if_very_busy():
    assert ids(rank_hospitals([FAR, NEAR], KL, triage_level=1)) == ["NEAR", "FAR"]


def test_level_5_is_steered_to_quieter_hospital():
    recs = rank_hospitals([NEAR, FAR], KL, triage_level=5)
    assert ids(recs) == ["FAR", "NEAR"]
    assert recs[0].badges == ["Best match", "Least busy"] and recs[1].badges == ["Closest"]


def test_no_triage_uses_middle_weight():
    # NEAR: ~2 min + 60 * 0.5 = 32; FAR: ~19 min + 0 = 19.
    assert ids(rank_hospitals([NEAR, FAR], KL, triage_level=None)) == ["FAR", "NEAR"]
    # A moderate near hospital (2 + 7.5) beats the far quiet one with no triage.
    near_moderate = row("NEAR_MOD", 3.1480, 101.6869, "moderate")
    assert ids(rank_hospitals([near_moderate, FAR], KL))[0] == "NEAR_MOD"


def test_skips_bad_coordinates_and_non_emergency_categories():
    rows = [row("NOCOORD", None, None), row("BAD", 999.0, 101.0), row("REHAB", 3.14, 101.69, category="rehabilitation"),
            row("PSY", 3.14, 101.69, category="mental_health"), NEAR]
    assert ids(rank_hospitals(rows, KL, 3)) == ["NEAR"]


def test_falls_back_to_nearest_when_none_in_radius():
    far_away = [row(f"H{i}", 5.0 + i * 0.1, 100.3) for i in range(8)]
    recs = rank_hospitals(far_away, KL, 3, max_radius_km=30, limit=10)
    assert len(recs) == 5 and recs[0].distance_km > 30


def test_limit_and_scores_in_range():
    rows = [row(f"H{i}", 3.14 + i * 0.01, 101.69, "busy") for i in range(10)]
    recs = rank_hospitals(rows, KL, 4, limit=3)
    assert len(recs) == 3 and all(0.0 <= r.suitability_score <= 1.0 for r in recs)


def test_live_traffic_reorders_and_partial_failure_keeps_estimate():
    # A is nearer in a straight line but stuck in traffic; B is a bit further but clear.
    a = row("A", 3.1480, 101.6869, "low")
    b = row("B", 3.1600, 101.6869, "low")
    times = {"A": (40, 3.1), "B": (9, 4.0)}
    seen = []

    def fake(lat, lon, destinations):
        seen.append([d.key for d in destinations])
        return [times.get(d.key) for d in destinations]

    recs = rank_hospitals([a, b], KL, 3, drive_time_fn=fake)
    assert ids(recs) == ["B", "A"] and seen == [["A", "B"]]
    assert recs[0].travel_time_source == "traffic" and recs[0].road_distance_km == 4.0
    assert recs[0].estimated_travel_time_minutes == 9 and "current traffic" in recs[0].recommendation_reason

    times.pop("A")  # no route for A: it keeps its straight-line estimate
    recs = rank_hospitals([a, b], KL, 3, drive_time_fn=fake)
    a_rec = next(r for r in recs if r.hospital.hospital_id == "A")
    assert a_rec.travel_time_source == "estimate" and a_rec.road_distance_km is None


def test_traffic_shortlist_is_by_score_not_distance():
    near_busy = [row(f"N{i}", 3.1400 + i * 0.001, 101.6869, "very busy") for i in range(3)]
    quiet_far = row("QUIET", 3.2390, 101.6869, "low")
    sent = []
    rank_hospitals(near_busy + [quiet_far], KL, 5, drive_time_fn=lambda la, lo, d: sent.extend(d) or [None] * len(d),
                   shortlist=2)
    assert "QUIET" in [d.key for d in sent]


def located(hid, status, place_id):
    # DB says ~11 km away; Google says ~1 km away.
    return HospitalActivityRow(hospital_id=hid, name=hid, category="unknown", address="", phone=None,
                               latitude=3.2390, longitude=101.6869, activity_level="low",
                               location_status=status, google_place_id=place_id,
                               google_latitude=3.1480, google_longitude=101.6869)


def test_google_location_used_only_on_mismatch():
    rows = [located("WRONG", "mismatch", "p1"), located("OK", "match", "p2"),
            located("REJECTED", "not_found", "p3"), located("UNSURE", "uncertain", "p4")]
    recs = {r.hospital.hospital_id: r for r in rank_hospitals(rows, KL, 3)}
    assert recs["WRONG"].distance_km < 2 and recs["WRONG"].hospital.location_source == "google"
    assert recs["WRONG"].hospital.google_place_id == "p1"
    assert recs["OK"].distance_km > 10 and recs["OK"].hospital.location_source == "database"
    assert recs["OK"].hospital.google_place_id == "p2"
    # A rejected or unsure Google candidate is never used to navigate or relocate.
    for hid in ("REJECTED", "UNSURE"):
        assert recs[hid].hospital.google_place_id is None and recs[hid].distance_km > 10


def seed():
    Base.metadata.create_all(get_engine())
    table = get_settings().WAIT_LABEL_TABLE
    with get_session_factory()() as db:
        db.execute(text(f'CREATE TABLE IF NOT EXISTS "{table}" (hospital_id TEXT PRIMARY KEY, '
                        f'activity_level TEXT, available_ed_spaces INTEGER)'))
        for h in (NEAR, FAR):
            if db.get(HospitalDirectory, h.hospital_id) is None:
                db.add(HospitalDirectory(hospital_id=h.hospital_id, hospital_name=h.name,
                                         latitude=h.latitude, longitude=h.longitude))
                db.execute(text(f'INSERT INTO "{table}" VALUES (:i, :a, 3)'),
                           {"i": h.hospital_id, "a": h.activity_level})
        for ident in ("route-user", "route-other"):
            if db.get(User, ident) is None:
                db.add(User(id=ident, ic=f"{len(ident)}0101-01-0000{ident[-1]}", name=ident,
                            email=f"{ident}@example.com", phone=f"019{ident[-3:]}", password_hash="x"))
        db.commit()


def add_report(db, session_id, user_id, level, age_hours, subject="self"):
    when = datetime.now(timezone.utc) - timedelta(hours=age_hours)
    db.add(SavedReport(session_id=session_id, user_id=user_id, subject=subject, main_symptom="x",
                       reported_severity="x", danger_signs="x", report={"level": level},
                       created_at=when, updated_at=when))
    db.commit()


def test_recent_triage_level_lookup():
    seed()
    service = RoutingService()
    with get_session_factory()() as db:
        assert service.recent_triage_level(db, None) == (None, None)
        add_report(db, "rt-old", "route-user", 1, age_hours=30)
        assert service.recent_triage_level(db, "route-user") == (None, None)
        add_report(db, "rt-other-person", "route-user", 2, age_hours=5, subject="other")
        add_report(db, "rt-new", "route-user", 4, age_hours=1)
        add_report(db, "rt-stranger", "route-other", 1, age_hours=0)
        level, age = service.recent_triage_level(db, "route-user")
        assert level == 4 and 0.9 <= age <= 1.1
        # The report the user came from wins over a newer one; old or foreign ones do not.
        assert service.recent_triage_level(db, "route-user", "rt-other-person")[0] == 2
        assert service.recent_triage_level(db, "route-user", "rt-old")[0] == 4
        assert service.recent_triage_level(db, "route-user", "rt-stranger")[0] == 4


@pytest.mark.asyncio
async def test_recommendations_endpoint():
    seed()
    auth = get_auth_service()
    auth._active_sessions["route-user-token"] = {"id": "route-user"}
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            url = "/api/hospitals/recommendations"
            assert (await client.get(url, params={"lat": 999, "lon": 101})).status_code == 422
            anon = (await client.get(url, params={"lat": KL.latitude, "lon": KL.longitude})).json()["data"]
            assert anon["triage_level_used"] is None
            assert {"NEAR", "FAR"} <= {r["hospital"]["hospital_id"] for r in anon["recommendations"]}
            with get_session_factory()() as db:
                add_report(db, "rt-endpoint", "route-user", 1, age_hours=0)
            mine = (await client.get(url, params={"lat": KL.latitude, "lon": KL.longitude},
                                     headers={"Authorization": "Bearer route-user-token"})).json()["data"]
            assert mine["triage_level_used"] == 1
            assert mine["recommendations"][0]["hospital"]["hospital_id"] == "NEAR"
            assert mine["recommendations"][0]["hospital"]["activity_level"] == "very busy"
    finally:
        auth._active_sessions.pop("route-user-token", None)
