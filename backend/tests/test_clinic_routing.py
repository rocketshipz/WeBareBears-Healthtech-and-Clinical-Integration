from datetime import datetime, timedelta, timezone

import pytest
from httpx import ASGITransport, AsyncClient

from app.api.routes.auth import get_auth_service
from app.main import app
from app.core.database import Base, get_engine, get_session_factory
from app.models.clinic_directory import ClinicDirectory
from app.models.clinic_place_check import ClinicPlaceCheck
from app.models.triage_report import SavedReport
from app.models.user import User
from app.repositories import clinic_repository
from app.repositories.clinic_repository import ClinicRepository, ClinicRow, display_name, is_walk_in_gp
from app.repositories.hospital_repository import HospitalActivityRow
from app.schemas.hospital import Coordinates
from app.services import clinic_hours_service, routing_service
from app.services.clinic_hours_service import check_clinic, expand_name, hours_for, needs_lookup, open_status
from app.services.routing_service import RoutingService, rank_clinics

KL = Coordinates(latitude=3.1390, longitude=101.6869)
MYT = timezone(timedelta(hours=8))


def clinic(code, lat, category="general_primary_care", **kw):
    return ClinicRow(clinic_code=code, name=code, category=category, clinic_type="private", address="",
                     phone=None, latitude=lat, longitude=101.6869, **kw)


def ids(recs):
    return [r.hospital.hospital_id for r in recs]


def test_walk_in_name_filter():
    assert is_walk_in_gp("KLINIK PERMATA (A33453)")  # "MATA" only as a whole word
    assert is_walk_in_gp("KLINIK DAN SURGERY LOO")  # "Surgery" = GP clinic in Malaysia
    assert is_walk_in_gp("KLINIK PERUBATAN DAN PEMBEDAHAN BUKIT 1")  # "medicine and surgery" = GP
    assert is_walk_in_gp("24 JAM POLIKLINIK YAP")
    assert is_walk_in_gp("KD LABU BESAR")
    assert not is_walk_in_gp("TAIPING EYE SPECIALIST AND SURGERY")
    assert not is_walk_in_gp("KLINIK PAKAR KULIT WAN")
    assert not is_walk_in_gp("PILLAY HEART CENTRE")
    # Malay / misspelt specialist names.
    for name in ("C. L. LEONG ORTOPIDIK SURGERI", "ENJER OTOPAEDIC SURGERY", "IPOH GASTRO CENTRE", "BP DIAGNOSTIK",
                 "DR. JOHN LOH (O&G) SDN. BHD", "CLINIC ENT TAN", "KLINIK PERGIGIAN NGO"):
        assert not is_walk_in_gp(name), name
    assert display_name("KLINIK TERRY LEE (A21401)") == "KLINIK TERRY LEE"


# Google periods: day 0 = Sunday, Malaysia local time.
WEEKDAYS_9_TO_5 = [{"open": {"day": d, "hour": 9, "minute": 0}, "close": {"day": d, "hour": 17, "minute": 0}}
                   for d in range(1, 6)]
# Friday 20:00 -> Saturday 02:00, plus Saturday 22:00 -> Sunday 03:00 (wraps past the end of the week).
OVERNIGHT = [{"open": {"day": 5, "hour": 20, "minute": 0}, "close": {"day": 6, "hour": 2, "minute": 0}},
             {"open": {"day": 6, "hour": 22, "minute": 0}, "close": {"day": 0, "hour": 3, "minute": 0}}]
ALWAYS = [{"open": {"day": 0, "hour": 0, "minute": 0}}]


def at(weekday_name_day, hour, minute=0):
    # 2026-10-19 is a Monday.
    days = {"mon": 19, "tue": 20, "fri": 23, "sat": 24, "sun": 25}
    return datetime(2026, 10, days[weekday_name_day], hour, minute, tzinfo=MYT)


def test_open_status():
    assert open_status(WEEKDAYS_9_TO_5, at("mon", 10)) == "open"
    assert open_status(WEEKDAYS_9_TO_5, at("mon", 8, 59)) == "closed"
    assert open_status(WEEKDAYS_9_TO_5, at("mon", 16, 45)) == "closed"  # closes within 30 min
    assert open_status(WEEKDAYS_9_TO_5, at("sun", 10)) == "closed"
    # Timezone: 02:00 UTC Monday = 10:00 in Malaysia.
    assert open_status(WEEKDAYS_9_TO_5, datetime(2026, 10, 19, 2, 0, tzinfo=timezone.utc)) == "open"
    assert open_status(OVERNIGHT, at("sat", 1)) == "open"
    assert open_status(OVERNIGHT, at("sun", 2)) == "open"  # Saturday night wraps into Sunday
    assert open_status(OVERNIGHT, at("sat", 12)) == "closed"
    assert open_status(ALWAYS, at("tue", 3)) == "open"
    assert open_status(None) == open_status([]) == "unknown"


def test_expand_name():
    assert expand_name("KD BUKIT SAPI") == "Klinik Desa BUKIT SAPI"
    assert expand_name("KK KUALA KANGSAR") == "Klinik Kesihatan KUALA KANGSAR"
    assert expand_name("KKOM KG. ACHEH") == "Klinik Komuniti KG. ACHEH"
    assert expand_name("KELINIK ANANDA") == "Klinik ANANDA"
    assert expand_name("POLIKELINIK PANGKOR") == "Poliklinik PANGKOR"
    assert expand_name("KLINIK KK") == "Klinik KK"  # "KK" is expanded only at the start


def place(name, lat, periods=None, status="OPERATIONAL", types=("doctor", "health"), address=""):
    return {"id": f"p-{name}", "displayName": {"text": name}, "location": {"latitude": lat, "longitude": 101.6869},
            "businessStatus": status, "regularOpeningHours": {"periods": periods} if periods else {},
            "types": list(types), "formattedAddress": address}


def gp_row(name="KLINIK FAMILI GAYA", address="NO. 12 JALAN MERANTI 3", postcode="31400"):
    return ClinicRow("K1", name, "unknown", "private", address, None, 3.1390, 101.6869, postcode=postcode,
                     city="IPOH", state="PERAK")


def test_check_clinic_matches_only_the_same_clinic():
    row = gp_row()
    near = check_clinic(row, [place("Klinik Famili Gaya", 3.1395, WEEKDAYS_9_TO_5)])
    assert near.status == "match" and near.opening_periods == WEEKDAYS_9_TO_5
    # Far away, no address agreement: maybe another clinic of that name.
    assert check_clinic(row, [place("Klinik Famili Gaya", 3.3000, WEEKDAYS_9_TO_5)]).status == "uncertain"
    # Far away but same postcode: the DB coordinate is wrong.
    moved = check_clinic(row, [place("Klinik Famili Gaya", 3.3000, address="12, Jalan Meranti 3, 31400 Ipoh")])
    assert moved.status == "mismatch"
    # A branch (an extra distinctive word) is used only nearby and when the address agrees.
    branch = "Klinik Famili Gaya Greentown"
    assert check_clinic(row, [place(branch, 3.1700)]).status == "uncertain"
    assert check_clinic(row, [place(branch, 3.1395)]).status == "uncertain"
    assert check_clinic(row, [place(branch, 3.1395, address="12 Jalan Meranti 3, 31400 Ipoh")]).status == "match"
    # City words are not branch words.
    assert check_clinic(row, [place("Klinik Famili Gaya Ipoh", 3.1395)]).status == "match"
    # Not a clinic: a school, a village, a hospital.
    desa = gp_row("KD SUNGAI LESONG", "SUNGAI LESONG", postcode=None)
    assert check_clinic(desa, [place("SK Sungai Lesong", 3.1395, types=("school",))]).status == "not_found"
    village = place("Kampung Sungai Lesong", 3.1395, types=("locality", "political"))
    assert check_clinic(desa, [village]).status == "not_found"
    assert check_clinic(desa, [place("Klinik Desa Sungai Lesong", 3.1395)]).status == "match"
    kk = gp_row("KK KUALA KANGSAR", "JALAN SULTAN", postcode=None)
    hospital_place = place("Kuala Kangsar Hospital", 3.1395, types=("hospital", "health"))
    assert check_clinic(kk, [hospital_place]).status == "not_found"
    # A different clinic next door is not this one; a small spelling difference is.
    ong = gp_row("KLINIK ONG (PERUBATAN)", "LOT 2676, JALAN DAMAR LAUT")
    assert check_clinic(ong, [place("Klinik Ho", 3.1391)]).status == "not_found"
    siputeh = gp_row("KD SIPUTEH", "SIPUTEH", postcode=None)
    assert check_clinic(siputeh, [place("Klinik Desa Siputih", 3.1395)]).status == "match"
    # Google lists it as a skin clinic / dentist: not a walk-in GP.
    skin = place("Klinik Amisi", 3.1395, types=("skin_care_clinic", "health"))
    assert check_clinic(gp_row("KLINIK AMISI"), [skin]).status == "not_gp"


def test_apply_check_uses_only_current_usable_checks():
    row = gp_row()
    row.apply_check(check_clinic(row, [place("Klinik Famili Gaya", 3.3000, WEEKDAYS_9_TO_5)]))
    # uncertain: hours, place id and location are not used
    assert row.opening_periods is None and row.google_place_id is None and row.latitude == 3.1390
    row.apply_check(check_clinic(row, [place("Klinik Famili Gaya", 3.1395, WEEKDAYS_9_TO_5)]))
    assert row.opening_periods == WEEKDAYS_9_TO_5 and not needs_lookup(row, datetime.now(timezone.utc))
    assert needs_lookup(row, datetime.now(timezone.utc) + timedelta(days=31))
    # mismatch: Google's location is used; the DB one is kept for later checks.
    row.apply_check(check_clinic(row, [place("Klinik Famili Gaya", 3.3000, address="31400 Ipoh")]))
    assert row.latitude == 3.3 and row.db_latitude == 3.1390
    # A check made under older rules is not trusted, and is redone.
    old = ClinicPlaceCheck(clinic_code="K1", status="match", opening_periods=WEEKDAYS_9_TO_5,
                           checked_at=datetime.now(timezone.utc), check_version=None)
    row.apply_check(old)
    assert row.opening_periods is None and row.latitude == 3.1390 and needs_lookup(row, datetime.now(timezone.utc))
    row.apply_check(check_clinic(row, [place("Klinik Famili Gaya", 3.1395, types=("dentist",))]))
    assert not row.routable


def test_rank_clinics_drops_closed_and_prefers_open():
    rows = [clinic("C_NEAR_CLOSED", 3.1400), clinic("C_NEAR_UNKNOWN", 3.1410), clinic("C_OPEN", 3.1480),
            clinic("C_GONE", 3.1405)]
    hours = {"C_NEAR_CLOSED": "closed", "C_NEAR_UNKNOWN": "unknown", "C_OPEN": "open", "C_GONE": "gone"}
    recs = rank_clinics(rows, KL, 4, hours_fn=lambda rs: {r.clinic_code: hours[r.clinic_code] for r in rs})
    # C_OPEN (~2 min) beats C_NEAR_UNKNOWN (~1 min + 10 min unknown-hours penalty).
    assert ids(recs) == ["C_OPEN", "C_NEAR_UNKNOWN"]
    assert recs[0].hospital.facility_type == "clinic" and recs[0].hospital.has_emergency_room is False
    assert recs[0].hospital.open_status == "open" and "Open now" in recs[0].badges
    assert "call ahead" in recs[1].recommendation_reason and recs[1].badges == ["Closest"]


def test_rank_clinics_uses_hours_of_every_clinic_in_range():
    # Ten nearer clinics with unknown hours do not hide a confirmed-open one slightly further away.
    rows = [clinic(f"U{i}", 3.1395 + i * 0.0002) for i in range(10)] + [clinic("OPEN", 3.1450)]
    seen = []

    def hours(rs):
        seen.extend(r.clinic_code for r in rs)
        return {r.clinic_code: "open" if r.clinic_code == "OPEN" else "unknown" for r in rs}

    assert ids(rank_clinics(rows, KL, 4, hours_fn=hours))[0] == "OPEN"
    assert seen[:3] == ["U0", "U1", "U2"] and len(seen) == 11  # all of them, nearest first


def test_hours_for_second_lookup_round_only_when_nothing_open(monkeypatch):
    rows = [clinic(f"C{i}", 3.1400 + i * 0.001) for i in range(3)]
    calls = []

    def fake_refresh(rs, now, limit=8):
        calls.append(1)
        return 1

    monkeypatch.setattr(clinic_hours_service, "refresh_hours", fake_refresh)
    assert set(hours_for(rows).values()) == {"unknown"} and len(calls) == 2
    calls.clear()
    rows[2].opening_periods = ALWAYS
    assert hours_for(rows)["C2"] == "open" and len(calls) == 1
    rows[1].business_status = "CLOSED_PERMANENTLY"
    rows[0].place_status = "not_gp"
    result = hours_for(rows)
    assert result["C1"] == "gone" and result["C0"] == "excluded"


def test_rank_clinics_klinik_desa_only_as_last_resort():
    gp = [clinic(f"GP{i}", 3.1400 + i * 0.001) for i in range(3)]
    desa = clinic("DESA", 3.1395, category="rural_clinic")
    assert "DESA" not in ids(rank_clinics(gp + [desa], KL, 5))
    all_closed = rank_clinics(gp + [desa], KL, 5,
                              hours_fn=lambda rs: {r.clinic_code: "closed" if r.clinic_code != "DESA" else "unknown"
                                                   for r in rs})
    assert ids(all_closed) == ["DESA"]
    assert ids(rank_clinics(gp + [desa], KL, 5, hours_fn=lambda rs: {r.clinic_code: "excluded" for r in rs})) == []
    # Nothing in range: empty, so routing falls back to hospitals.
    assert rank_clinics([clinic("FAR", 5.0)], KL, 4, max_radius_km=30) == []


def hospital(hid, lat):
    return HospitalActivityRow(hospital_id=hid, name=hid, category="unknown", address="", phone=None,
                               latitude=lat, longitude=101.6869, activity_level="low")


def seed_clinics():
    Base.metadata.create_all(get_engine())
    with get_session_factory()() as db:
        for code, name, category, lat in [("TC1", "KLINIK DEKAT", "unknown", "3.1400"),
                                          ("TC2", "KLINIK MATA SPECIALIST", "unknown", "3.1395"),
                                          ("TC3", "KD KAMPUNG", "rural_clinic", "3.1392"),
                                          ("TC4", "KLINIK TANPA LOKASI", "unknown", None),
                                          ("TC5", "KKIA DEKAT", "women_maternal", "3.1391"),
                                          ("TC6", "KLINIK GIGI SENYAP", "unknown", "3.1393")]:
            if db.get(ClinicDirectory, code) is None:
                db.add(ClinicDirectory(clinic_code=code, clinic_name=name, clinic_category=category,
                                       clinic_type="private", latitude=lat, longitude="101.6869", postcode=31400))
        if db.get(ClinicPlaceCheck, "TC6") is None:  # Google says TC6 is a dentist
            db.add(ClinicPlaceCheck(clinic_code="TC6", status="not_gp", check_version=clinic_repository.CHECK_VERSION))
        db.commit()
    clinic_repository.clear_cache()


def test_repository_filters_clinics():
    seed_clinics()
    with get_session_factory()() as db:
        rows = {r.clinic_code: r for r in ClinicRepository(db).list_routable()}
    assert {"TC1", "TC3"} <= set(rows) and not {"TC2", "TC4", "TC5", "TC6"} & set(rows)
    assert rows["TC1"].latitude == 3.14 and rows["TC3"].is_rural and rows["TC1"].postcode == "31400"


def test_level_4_5_get_clinics_then_one_ed(monkeypatch):
    seed_clinics()
    monkeypatch.setattr(routing_service.HospitalRepository, "list_with_activity",
                        lambda self: [hospital("H_NEAR", 3.1480), hospital("H_FAR", 3.2390)])
    service = RoutingService()
    with get_session_factory()() as db:
        for level in (4, 5):
            recs = service.recommend_hospitals(KL, triage_level=level, db_session=db, limit=5)
            types = [r.hospital.facility_type for r in recs]
            assert types[0] == "clinic" and types[-1] == "hospital" and types.count("hospital") == 1
            assert recs[-1].badges == ["ED backup"] and "TC1" in ids(recs)
        for level in (1, 2, 3, None):
            recs = service.recommend_hospitals(KL, triage_level=level, db_session=db, limit=5)
            assert {r.hospital.facility_type for r in recs} == {"hospital"}
        # No clinic in range: hospitals only, as for other levels.
        far = Coordinates(latitude=6.0, longitude=116.0)
        recs = service.recommend_hospitals(far, triage_level=4, db_session=db, limit=5)
        assert {r.hospital.facility_type for r in recs} == {"hospital"}


def add_user(db, ident):
    if db.get(User, ident) is None:
        db.add(User(id=ident, ic=f"{ident}-ic", name=ident, email=f"{ident}@example.com", phone=f"{ident}-phone",
                    password_hash="x"))
        db.commit()


def add_report(db, session_id, user_id, level, when):
    db.add(SavedReport(session_id=session_id, user_id=user_id, subject="self", main_symptom="x",
                       reported_severity="x", danger_signs="x", report={"level": level},
                       created_at=when, updated_at=when))
    db.commit()


def test_clearing_triage_result_only_hides_older_reports():
    seed_clinics()
    service = RoutingService()
    now = datetime.now(timezone.utc)
    with get_session_factory()() as db:
        add_user(db, "clear-user")
        add_report(db, "clear-1", "clear-user", 4, now - timedelta(hours=2))
        assert service.recent_triage_level(db, "clear-user", now=now)[0] == 4
        service.clear_recent_triage(db, "clear-user", now=now - timedelta(hours=1))
        assert service.recent_triage_level(db, "clear-user", now=now) == (None, None)
        # Also when the routing page passes that report's session id.
        assert service.recent_triage_level(db, "clear-user", "clear-1", now=now) == (None, None)
        # A triage made after clearing is used again.
        add_report(db, "clear-2", "clear-user", 2, now - timedelta(minutes=30))
        assert service.recent_triage_level(db, "clear-user", now=now)[0] == 2


def test_clinics_listed_separately_only_without_recent_triage(monkeypatch):
    seed_clinics()
    monkeypatch.setattr(routing_service.HospitalRepository, "list_with_activity",
                        lambda self: [hospital("H_NEAR", 3.1480), hospital("H_FAR", 3.2390)])
    service = RoutingService()
    now = datetime.now(timezone.utc)
    with get_session_factory()() as db:
        none = service.recommend_for_user(db, KL, user_id=None, limit=5, clinics=5)
        assert {r.hospital.facility_type for r in none.recommendations} == {"hospital"}
        assert none.clinic_recommendations and \
            {r.hospital.facility_type for r in none.clinic_recommendations} == {"clinic"}
        assert "not for emergencies" in none.clinic_recommendations[0].recommendation_reason
        assert service.recommend_for_user(db, KL, limit=5).clinic_recommendations == []
        add_user(db, "sep-user")
        add_report(db, "sep-1", "sep-user", 2, now - timedelta(minutes=5))
        triaged = service.recommend_for_user(db, KL, user_id="sep-user", limit=5, clinics=5)
        assert triaged.triage_level_used == 2 and triaged.clinic_recommendations == []


@pytest.mark.asyncio
async def test_clear_triage_endpoint(monkeypatch):
    seed_clinics()
    monkeypatch.setattr(routing_service.HospitalRepository, "list_with_activity",
                        lambda self: [hospital("H_NEAR", 3.1480)])
    with get_session_factory()() as db:
        add_user(db, "ep-clear")
        add_report(db, "ep-clear-1", "ep-clear", 5, datetime.now(timezone.utc) - timedelta(minutes=10))
    auth = get_auth_service()
    auth._active_sessions["ep-clear-token"] = {"id": "ep-clear"}
    headers = {"Authorization": "Bearer ep-clear-token"}
    try:
        async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
            assert (await client.delete("/api/hospitals/triage-context")).status_code == 401
            params = {"lat": KL.latitude, "lon": KL.longitude, "limit": 5, "clinics": 5}
            before = (await client.get("/api/hospitals/recommendations", params=params, headers=headers)).json()
            assert before["data"]["triage_level_used"] == 5
            assert (await client.delete("/api/hospitals/triage-context", headers=headers)).status_code == 200
            after = (await client.get("/api/hospitals/recommendations", params=params, headers=headers)).json()
            assert after["data"]["triage_level_used"] is None
            assert after["data"]["clinic_recommendations"]
    finally:
        auth._active_sessions.pop("ep-clear-token", None)
