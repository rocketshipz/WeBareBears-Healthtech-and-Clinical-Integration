import logging
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Callable, Dict, List, Optional, Sequence, Tuple

from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.services import clinic_hours_service, traffic_service
from app.services.traffic_service import Destination

from app.schemas.hospital import (
    Coordinates,
    HospitalInfo,
    HospitalRecommendation,
    HospitalRoutingResponse,
)
from app.services.hospital_service import HospitalService
from app.repositories.clinic_repository import ClinicRepository, ClinicRow
from app.repositories.hospital_repository import HospitalActivityRow, HospitalRepository
from app.models.routing_triage_clear import RoutingTriageClear
from app.repositories.triage_report_repository import TriageReportRepository
from app.core.location_detector import (
    calculate_haversine_distance,
    estimate_travel_time_minutes,
    is_valid_coordinates,
)

logger = logging.getLogger(__name__)

# Ranking: score = travel minutes + busyness penalty (minutes) * weight for the triage level. Lower is better.
# The triage level only shapes the ranking; routing never changes the level.
ACTIVITY_PENALTY_MINUTES = {"low": 0, "moderate": 15, "busy": 30, "very busy": 60}
UNKNOWN_ACTIVITY_PENALTY_MINUTES = 15
# Level 1-2 go to the nearest ED whatever its load; Level 4-5 are steered to quieter ones further away.
LEVEL_WEIGHT = {1: 0.0, 2: 0.25, 3: 0.5, 4: 1.0, 5: 1.0}
NO_TRIAGE_WEIGHT = 0.5  # no triage in the last TRIAGE_MAX_AGE
TRIAGE_MAX_AGE = timedelta(hours=24)
# Not emergency departments.
EXCLUDED_CATEGORIES = {"rehabilitation", "mental_health"}
FALLBACK_NEAREST = 5  # used when nothing is within the radius, so the list is never empty

# Level 4-5: walk-in clinics first (KB level_advice: L4 "ED or a walk-in clinic", L5 "a clinic is suitable"),
# then the best ED as a backup. If no clinic is open or in range, the hospital list is used as for other levels.
CLINIC_LEVELS = {4, 5}
CLINIC_TRAFFIC_SHORTLIST = 10  # best clinics (by estimate) sent to the route matrix
UNKNOWN_HOURS_PENALTY_MINUTES = 10  # a clinic Google confirms open beats a slightly nearer one with unknown hours


def activity_penalty(activity_level: Optional[str]) -> int:
    return ACTIVITY_PENALTY_MINUTES.get((activity_level or "").strip().lower(), UNKNOWN_ACTIVITY_PENALTY_MINUTES)


def level_weight(triage_level: Optional[int]) -> float:
    return LEVEL_WEIGHT.get(triage_level, NO_TRIAGE_WEIGHT)


def _reason(c: "_Candidate", triage_level: Optional[int]) -> str:
    drive = f"{c.minutes} min drive" + (" in current traffic" if c.road_km is not None else "")
    if triage_level in (1, 2):
        return f"{drive} · nearest emergency care matters most for a Level {triage_level} result"
    activity = (c.row.activity_level or "").strip().lower()
    return f"{drive} · {activity} ED" if activity else f"{drive} · ED activity unknown"


@dataclass
class _Candidate:
    row: HospitalActivityRow
    latitude: float
    longitude: float
    dist_km: float  # straight line
    minutes: int  # estimate, replaced by live traffic when available
    penalty: int
    road_km: Optional[float] = None  # set only when minutes come from live traffic

    def score(self, weight: float) -> float:
        return self.minutes + self.penalty * weight


# (patient lat, patient lon, destinations) -> (minutes, road km) or None per destination.
DriveTimeFn = Callable[[float, float, Sequence[Destination]], List[Optional[Tuple[int, float]]]]


def rank_hospitals(
    rows: Sequence[HospitalActivityRow],
    patient_location: Coordinates,
    triage_level: Optional[int] = None,
    max_radius_km: float = 30.0,
    limit: int = 5,
    drive_time_fn: Optional[DriveTimeFn] = None,
    shortlist: int = 15,
) -> List[HospitalRecommendation]:
    """Ranks hospitals by travel time plus a busyness penalty weighted by the triage level.

    Stage 1 scores every hospital with the straight-line estimate. Stage 2 (when drive_time_fn is given)
    replaces the minutes of the best `shortlist` with live-traffic driving times and re-ranks them.
    Hospitals Google gives no time for keep their estimate.
    """
    weight = level_weight(triage_level)
    candidates = []
    for row in rows:
        if (row.category or "").strip().lower() in EXCLUDED_CATEGORIES:
            continue
        lat, lon = row.best_latitude, row.best_longitude
        if lat is None or lon is None or not is_valid_coordinates(lat, lon):
            continue
        dist_km = calculate_haversine_distance(patient_location.latitude, patient_location.longitude, lat, lon)
        candidates.append(_Candidate(row, lat, lon, dist_km, estimate_travel_time_minutes(dist_km),
                                     activity_penalty(row.activity_level)))

    in_range = [c for c in candidates if c.dist_km <= max_radius_km]
    if not in_range:
        in_range = sorted(candidates, key=lambda c: c.dist_km)[:FALLBACK_NEAREST]
    # Shortlisted by estimate score (not plain distance), so Level 4-5 can still reach quieter EDs further out.
    pool = sorted(in_range, key=lambda c: (c.score(weight), c.dist_km))[:max(shortlist, limit, 0)]

    if drive_time_fn is not None and pool:
        destinations = [Destination(c.row.hospital_id, c.latitude, c.longitude, c.row.google_place_id)
                        for c in pool]
        for c, drive in zip(pool, drive_time_fn(patient_location.latitude, patient_location.longitude,
                                                destinations)):
            if drive is not None:
                c.minutes, c.road_km = drive

    chosen = sorted(pool, key=lambda c: (c.score(weight), c.dist_km))[:max(limit, 0)]
    if not chosen:
        return []

    max_score = max(c.score(weight) for c in chosen) or 1.0
    # Each badge goes to one hospital only: the highest-ranked one that qualifies.
    closest = min(range(len(chosen)), key=lambda i: chosen[i].road_km or chosen[i].dist_km)
    known = [i for i, c in enumerate(chosen) if c.row.activity_level]
    least_busy = min(known, key=lambda i: chosen[i].penalty) if known else None
    results = []
    for rank, c in enumerate(chosen):
        row = c.row
        badges = []
        if rank == 0:
            badges.append("Best match")
        if rank == closest:
            badges.append("Closest")
        if rank == least_busy:
            badges.append("Least busy")
        results.append(HospitalRecommendation(
            hospital=HospitalInfo(
                hospital_id=row.hospital_id,
                name=row.name or row.hospital_id,
                address=row.address or "",
                location=Coordinates(latitude=c.latitude, longitude=c.longitude),
                phone_number=row.phone,
                activity_level=row.activity_level,
                available_ed_spaces=row.available_ed_spaces,
                google_place_id=row.google_place_id,
                location_source="google" if row.uses_google_location else "database",
            ),
            distance_km=round(c.dist_km, 2),
            estimated_travel_time_minutes=c.minutes,
            travel_time_source="traffic" if c.road_km is not None else "estimate",
            road_distance_km=c.road_km,
            suitability_score=(round(min(max(1.0 - c.score(weight) / max_score, 0.0), 1.0), 3)
                               if len(chosen) > 1 else 1.0),
            recommendation_reason=_reason(c, triage_level),
            badges=badges,
        ))
    return results


@dataclass
class _ClinicCandidate:
    row: ClinicRow
    dist_km: float
    minutes: int
    hours: str = "unknown"  # open | unknown (closed ones are dropped)
    road_km: Optional[float] = None

    def score(self) -> float:
        return self.minutes + (UNKNOWN_HOURS_PENALTY_MINUTES if self.hours != "open" else 0)


# clinic rows (nearest first) -> clinic_code -> "open" | "closed" | "unknown" | "gone" | "excluded".
# Only "open" and "unknown" clinics are recommended.
HoursFn = Callable[[Sequence[ClinicRow]], Dict[str, str]]


def _clinic_reason(c: _ClinicCandidate, triage_level: Optional[int]) -> str:
    drive = f"{c.minutes} min drive" + (" in current traffic" if c.road_km is not None else "")
    hours = "open now" if c.hours == "open" else "opening hours not verified, call ahead"
    suits = f"a clinic suits a Level {triage_level} result" if triage_level else "walk-in clinic, not for emergencies"
    return f"{drive} · {hours} · {suits}"


def rank_clinics(
    rows: Sequence[ClinicRow],
    patient_location: Coordinates,
    triage_level: Optional[int] = None,
    max_radius_km: float = 30.0,
    limit: int = 4,
    hours_fn: Optional[HoursFn] = None,
    drive_time_fn: Optional[DriveTimeFn] = None,
    shortlist: int = CLINIC_TRAFFIC_SHORTLIST,
) -> List[HospitalRecommendation]:
    """Walk-in clinics within the radius that are not known to be closed, nearest first.

    GP-type clinics are used; Klinik Desa only when no GP-type clinic is left. Every clinic in range gets its
    hours status (hours_fn looks up only the nearest unchecked ones on Google). Closed clinics are dropped, and a
    clinic confirmed open ranks ahead of a nearer one with unknown hours (UNKNOWN_HOURS_PENALTY_MINUTES).
    Empty when nothing is in range, so the caller falls back to hospitals.
    """
    if limit <= 0:
        return []
    in_range = []
    for row in rows:
        if not row.routable:
            continue
        dist_km = calculate_haversine_distance(patient_location.latitude, patient_location.longitude,
                                               row.latitude, row.longitude)
        if dist_km <= max_radius_km:
            in_range.append(_ClinicCandidate(row, dist_km, estimate_travel_time_minutes(dist_km)))
    in_range.sort(key=lambda c: c.dist_km)

    kept: List[_ClinicCandidate] = []
    for tier in ([c for c in in_range if not c.row.is_rural], [c for c in in_range if c.row.is_rural]):
        if not tier:
            continue
        hours = hours_fn([c.row for c in tier]) if hours_fn else {}
        for c in tier:
            c.hours = hours.get(c.row.clinic_code, "unknown")
        kept = [c for c in tier if c.hours in ("open", "unknown")]
        if kept:
            break

    # Live traffic only for the best few by estimate, as for hospitals.
    pool = sorted(kept, key=lambda c: (c.score(), c.dist_km))[:max(shortlist, limit)]
    if drive_time_fn is not None and pool:
        destinations = [Destination(c.row.clinic_code, c.row.latitude, c.row.longitude, c.row.google_place_id)
                        for c in pool]
        for c, drive in zip(pool, drive_time_fn(patient_location.latitude, patient_location.longitude,
                                                destinations)):
            if drive is not None:
                c.minutes, c.road_km = drive

    chosen = sorted(pool, key=lambda c: (c.score(), c.dist_km))[:limit]
    if not chosen:
        return []
    max_score = max(c.score() for c in chosen) or 1.0
    closest = min(range(len(chosen)), key=lambda i: chosen[i].road_km or chosen[i].dist_km)
    results = []
    for rank, c in enumerate(chosen):
        row = c.row
        badges = []
        if rank == 0:
            badges.append("Best match")
        if rank == closest:
            badges.append("Closest")
        if c.hours == "open":
            badges.append("Open now")
        results.append(HospitalRecommendation(
            hospital=HospitalInfo(
                hospital_id=row.clinic_code,
                name=row.name,
                address=row.address or "",
                location=Coordinates(latitude=row.latitude, longitude=row.longitude),
                phone_number=row.phone,
                has_emergency_room=False,
                google_place_id=row.google_place_id,
                facility_type="clinic",
                clinic_type=row.clinic_type,
                open_status=c.hours,
            ),
            distance_km=round(c.dist_km, 2),
            estimated_travel_time_minutes=c.minutes,
            travel_time_source="traffic" if c.road_km is not None else "estimate",
            road_distance_km=c.road_km,
            suitability_score=(round(min(max(1.0 - c.score() / max_score, 0.0), 1.0), 3)
                               if len(chosen) > 1 else 1.0),
            recommendation_reason=_clinic_reason(c, triage_level),
            badges=badges,
        ))
    return results


def with_ed_backup(clinics: List[HospitalRecommendation],
                   hospitals: List[HospitalRecommendation]) -> List[HospitalRecommendation]:
    """Clinics, then the best hospital ED (if any) marked as the backup."""
    if not hospitals:
        return clinics
    ed = hospitals[0]
    return clinics + [ed.model_copy(update={
        "badges": ["ED backup"],
        "suitability_score": 0.0,  # listed in case symptoms get worse, not as a match for this level
        "recommendation_reason": f"{ed.recommendation_reason.split(' · ')[0]} · "
                                 f"emergency department, if symptoms get worse",
    })]


def _as_utc(value: datetime) -> datetime:
    return value if value.tzinfo else value.replace(tzinfo=timezone.utc)


class RoutingService:
    """Service layer for calculating hospital routing and suitability recommendations."""

    def __init__(self, hospital_service: Optional[HospitalService] = None):
        self.hospital_service = hospital_service or HospitalService()

    def calculate_distance_and_time(
        self,
        patient_location: Coordinates,
        hospital_lat: float,
        hospital_lon: float
    ) -> Tuple[float, int]:
        """Calculate great-circle distance (km) and estimated travel time (min)."""
        dist_km = calculate_haversine_distance(
            patient_location.latitude,
            patient_location.longitude,
            hospital_lat,
            hospital_lon
        )
        travel_time = estimate_travel_time_minutes(dist_km)
        return dist_km, travel_time

    def recommend_hospitals(
        self,
        patient_location: Coordinates,
        required_specialties: Optional[List[str]] = None,
        triage_level: Optional[int] = None,
        max_radius_km: float = 30.0,
        limit: int = 5,
        db_session: Optional[Session] = None,
    ) -> List[HospitalRecommendation]:
        """Hospitals near the patient, ranked by travel time (live traffic when available) and ED busyness
        weighted by triage level. Level 4-5: walk-in clinics first, then the best ED as a backup.

        Without a database session there is no hospital data, so the list is empty.
        A triage_level that is not a level number 1-5 counts as no triage.
        """
        if db_session is None:
            return []
        level = triage_level if isinstance(triage_level, int) and triage_level in LEVEL_WEIGHT else None
        rows = HospitalRepository(db_session).list_with_activity()
        shortlist = get_settings().ROUTING_TRAFFIC_SHORTLIST
        if level in CLINIC_LEVELS:
            clinics = rank_clinics(ClinicRepository(db_session).list_routable(), patient_location, level,
                                   max_radius_km, limit=max(limit - 1, 1),
                                   hours_fn=clinic_hours_service.hours_for,
                                   drive_time_fn=traffic_service.drive_times)
            if clinics:
                if limit <= 1:
                    return clinics
                return with_ed_backup(clinics, rank_hospitals(
                    rows, patient_location, level, max_radius_km, limit=1,
                    drive_time_fn=traffic_service.drive_times, shortlist=shortlist))
        return rank_hospitals(rows, patient_location, level, max_radius_km, limit,
                              drive_time_fn=traffic_service.drive_times, shortlist=shortlist)

    def recent_triage_level(
        self,
        db_session: Session,
        user_id: Optional[str],
        session_id: Optional[str] = None,
        now: Optional[datetime] = None,
    ) -> Tuple[Optional[int], Optional[float]]:
        """(level, age in hours) of the user's triage from the last 24 h, or (None, None).

        A given session_id (the report the user came from) is used if it is theirs and recent;
        otherwise the newest report they ran or are linked to.
        """
        if not user_id:
            return None, None
        now = now or datetime.now(timezone.utc)
        since = now - TRIAGE_MAX_AGE
        cleared = self._cleared_at(db_session, user_id)
        if cleared is not None and cleared > since:
            since = cleared  # the user cleared their triage result: older reports no longer shape routing
        repo = TriageReportRepository(db_session)
        row = None
        if session_id:
            owned = repo.get_owned(session_id, user_id)
            if owned is not None and _as_utc(owned.updated_at or owned.created_at) >= since:
                row = owned
        if row is None:
            row = repo.latest_recent(user_id, since)
        if row is None:
            return None, None
        try:
            level = int((row.report or {}).get("level"))
        except (TypeError, ValueError):
            return None, None
        if level not in LEVEL_WEIGHT:
            return None, None
        age_hours = (now - _as_utc(row.updated_at or row.created_at)).total_seconds() / 3600
        return level, round(max(age_hours, 0.0), 1)

    @staticmethod
    def _cleared_at(db_session: Session, user_id: str) -> Optional[datetime]:
        RoutingTriageClear.__table__.create(db_session.get_bind(), checkfirst=True)
        row = db_session.get(RoutingTriageClear, user_id)
        return _as_utc(row.cleared_at) if row is not None else None

    def clear_recent_triage(self, db_session: Session, user_id: str, now: Optional[datetime] = None) -> None:
        """Routing stops using the user's triage reports saved up to now. The reports themselves are kept."""
        RoutingTriageClear.__table__.create(db_session.get_bind(), checkfirst=True)
        db_session.merge(RoutingTriageClear(user_id=user_id, cleared_at=now or datetime.now(timezone.utc)))
        db_session.commit()
        logger.info(f"[RoutingService] User {user_id} cleared their recent triage result from routing.")

    def recommend_for_user(
        self,
        db_session: Session,
        patient_location: Coordinates,
        user_id: Optional[str] = None,
        session_id: Optional[str] = None,
        max_radius_km: float = 30.0,
        limit: int = 5,
        clinics: int = 0,
    ) -> HospitalRoutingResponse:
        """Ranked hospitals for the routing page, shaped by the user's triage level from the last 24 h.

        With no recent triage and clinics > 0, walk-in clinics are also ranked, as a separate list.
        """
        level, age_hours = self.recent_triage_level(db_session, user_id, session_id)
        logger.info(f"[RoutingService] Ranking hospitals for user={user_id} with triage level={level}.")
        clinic_recs = []
        if level is None and clinics > 0:
            clinic_recs = rank_clinics(ClinicRepository(db_session).list_routable(), patient_location, None,
                                       max_radius_km, limit=clinics, hours_fn=clinic_hours_service.hours_for,
                                       drive_time_fn=traffic_service.drive_times)
        return HospitalRoutingResponse(
            triage_level_used=level,
            triage_age_hours=age_hours,
            recommendations=self.recommend_hospitals(
                patient_location, triage_level=level, max_radius_km=max_radius_km,
                limit=limit, db_session=db_session,
            ),
            clinic_recommendations=clinic_recs,
        )
