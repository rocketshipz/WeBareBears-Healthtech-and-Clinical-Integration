"""Clinic opening hours from Google Places, looked up lazily for shortlisted clinics and stored in clinic_place_check.

Each clinic costs one Places Text Search call (Enterprise SKU, because of regularOpeningHours) per RECHECK_AFTER.
Without a key, with CLINIC_HOURS_LOOKUP off, or on any Google failure, hours are "unknown" and routing carries on.
"""
import logging
import re
import threading
import time
from concurrent.futures import ThreadPoolExecutor, wait
from datetime import datetime, timedelta, timezone
from difflib import SequenceMatcher
from typing import Dict, Optional, Sequence

import httpx

from app.core.config import get_settings
from app.core.database import get_session_factory
from app.core.location_detector import calculate_haversine_distance
from app.models.clinic_place_check import ClinicPlaceCheck
from app.repositories.clinic_repository import CHECK_VERSION, ClinicRow
from app.services.hospital_location_service import (
    MIN_SIMILARITY_IF_SAME_PLACE,
    MIN_NAME_SIMILARITY,
    name_similarity,
    normalise_name,
    search_places,
)

logger = logging.getLogger(__name__)

MALAYSIA_TZ = timezone(timedelta(hours=8))  # no daylight saving
CLINIC_FIELDS = ("places.id,places.displayName,places.location,places.businessStatus,"
                 "places.regularOpeningHours,places.formattedAddress,places.types")
MATCH_MAX_KM = 1.5  # Google's place must be this close to the DB coordinate, unless the address confirms it
SAME_BUILDING_KM = 0.3  # a weaker name match is accepted this close
RECHECK_AFTER = timedelta(days=30)
CLOSING_SOON_MINUTES = 30  # a clinic closing within this is treated as closed
LOOKUPS_PER_ROUND = 8  # Google lookups per request, nearest unchecked clinics first
LOOKUP_ROUNDS = 2  # a second round only when nothing in range is confirmed open (e.g. evenings)
FAILURE_BACKOFF_SECONDS = 60
_WEEK = 7 * 24 * 60

# Google place types. A doctor / clinic type is required; a place typed only as one of NOT_GP_TYPES
# (dentist, lab, skin clinic…) means the clinic is not a walk-in GP.
GP_TYPES = {"doctor", "medical_clinic", "medical_center", "hospital", "general_hospital"}
NOT_GP_TYPES = {"dentist", "dental_clinic", "medical_lab", "skin_care_clinic", "physiotherapist",
                "pharmacy", "drugstore", "chiropractor", "spa", "beauty_salon", "massage"}

# clinic_data abbreviations, expanded so Google finds the clinic rather than a village or school of that name.
_ABBREVIATIONS = [(re.compile(rf"^\s*{short}\b\.?", re.IGNORECASE), long) for short, long in (
    ("KKIA", "Klinik Kesihatan Ibu dan Anak"), ("KKOM", "Klinik Komuniti"), ("KK", "Klinik Kesihatan"),
    ("KD", "Klinik Desa"), ("KB", "Klinik Bergerak"))]
_SPELLING = [(re.compile(r"\bKE?LI?NI?[CK]\b", re.IGNORECASE), "Klinik"),
             (re.compile(r"\bPOLI?KE?LI?NI?[CK]\b", re.IGNORECASE), "Poliklinik")]
# Words that say nothing about which clinic it is; any other word Google adds suggests another branch.
_NAME_FILLER = {"klinik", "clinic", "poliklinik", "polyclinic", "dan", "and", "surgeri", "surgery", "dr", "doctor",
                "medical", "medic", "family", "keluarga", "perubatan", "pembedahan", "centre", "center", "pusat",
                "kesihatan", "desa", "komuniti", "community", "health", "care", "24", "jam", "hours", "the", "of",
                "umum", "general", "practice", "group", "kerajaan", "government"}
_ADDRESS_FILLER = {"no", "jalan", "jln", "lorong", "lrg", "taman", "tmn", "lot", "tingkat", "bawah", "ground",
                   "floor", "gf", "kampung", "kampong", "kg", "pekan", "bandar", "baru", "persiaran", "jalan",
                   "main", "road", "street", "off", "batu", "bt", "malaysia", "perak", "selangor", "johor"}

_executor = ThreadPoolExecutor(max_workers=8, thread_name_prefix="clinic-hours")
_failed_at: Optional[float] = None
_in_flight: set = set()
_in_flight_lock = threading.Lock()


def reset_backoff() -> None:
    global _failed_at
    _failed_at = None


def expand_name(name: str) -> str:
    """"KD BUKIT SAPI" -> "Klinik Desa BUKIT SAPI", "KELINIK ANANDA" -> "Klinik ANANDA"."""
    for pattern, long in _ABBREVIATIONS:
        if pattern.search(name or ""):
            name = pattern.sub(long, name, count=1)
            break
    for pattern, fixed in _SPELLING:
        name = pattern.sub(fixed, name)
    return name


def _words(text: str) -> set:
    return set(normalise_name(text).split())


def _minute_of_week(point: dict) -> int:
    return point.get("day", 0) * 1440 + point.get("hour", 0) * 60 + point.get("minute", 0)


def _open_at(periods: Sequence[dict], minute: int) -> bool:
    for period in periods:
        start = period.get("open")
        if not start:
            continue
        end = period.get("close")
        if end is None:  # Google's form for open 24 hours, 7 days
            return True
        a, b = _minute_of_week(start), _minute_of_week(end)
        if b <= a:  # wraps past Saturday midnight
            b += _WEEK
        if a <= minute < b or a <= minute + _WEEK < b:
            return True
    return False


def open_status(periods: Optional[Sequence[dict]], now: Optional[datetime] = None) -> str:
    """"open" | "closed" | "unknown" for Google's regularOpeningHours.periods (day 0 = Sunday, local time).

    "open" means open now and still open CLOSING_SOON_MINUTES from now. No periods = unknown.
    """
    if not periods:
        return "unknown"
    local = (now or datetime.now(timezone.utc)).astimezone(MALAYSIA_TZ)
    minute = ((local.weekday() + 1) % 7) * 1440 + local.hour * 60 + local.minute
    later = (minute + CLOSING_SOON_MINUTES - 1) % _WEEK
    return "open" if _open_at(periods, minute) and _open_at(periods, later) else "closed"


def is_medical(place: dict) -> bool:
    """A doctor / clinic / hospital, or a health place that is not only a dentist, lab, pharmacy…"""
    types = set(place.get("types") or [])
    return bool(types & GP_TYPES or types & NOT_GP_TYPES or "health" in types)


def is_not_gp(place: dict) -> bool:
    types = set(place.get("types") or [])
    return bool(types & NOT_GP_TYPES) and not types & GP_TYPES


def address_agrees(row: ClinicRow, google_address: Optional[str]) -> bool:
    """Google's address has the clinic's postcode, or most of its distinctive address words (street number…)."""
    if not google_address:
        return False
    if row.postcode and row.postcode in google_address:
        return True
    ours = {w for w in _words(row.address or "") if w not in _ADDRESS_FILLER}
    if len(ours) < 2:
        return False
    return len(ours & _words(google_address)) / len(ours) >= 0.5


def _same_word(a: str, b: str) -> bool:
    return a == b or (len(a) > 3 and len(b) > 3 and SequenceMatcher(None, a, b).ratio() >= 0.8)


def distinctive_words_agree(ours: str, google_name: str) -> bool:
    """At least half of the words that identify our clinic ("Ong" in "Klinik Ong") are in Google's name, allowing
    small spelling differences ("Siputeh" / "Siputih"). "Klinik Ong" is not "Klinik Ho"."""
    mine = {w for w in _words(expand_name(ours)) - _NAME_FILLER if len(w) > 1}
    theirs = _words(expand_name(google_name))
    if not mine:
        return True
    found = sum(1 for w in mine if any(_same_word(w, t) for t in theirs))
    return found * 2 >= len(mine)


def other_branch(row: ClinicRow, google_name: str) -> bool:
    """Google's name adds a distinctive word not in the clinic's name or address ("Klinik Terry Lee Ipoh Parade")."""
    known = _words(expand_name(row.name)) | _words(row.address or "") | _words(row.city or "") | \
        _words(row.state or "") | _NAME_FILLER
    return any(len(w) > 1 and not any(_same_word(w, k) for k in known)
               for w in _words(expand_name(google_name)) - known)


def check_clinic(row: ClinicRow, places: Sequence[dict]) -> ClinicPlaceCheck:
    """Matches one clinic to a Google place.

    match: near the DB coordinate (an extra word in Google's name needs the address to agree).
    mismatch: far from the DB coordinate, but the name and the postcode/address agree: the DB coordinate is wrong.
    uncertain: anything else with a similar name (maybe another branch). not_gp: Google lists it as a dentist, lab…
    """
    ours = expand_name(row.name)

    def dist(p):
        return calculate_haversine_distance(row.db_latitude, row.db_longitude,
                                            p["location"]["latitude"], p["location"]["longitude"])

    def gname(p):
        return (p.get("displayName") or {}).get("text", "")

    def similarity(p):
        return name_similarity(ours, expand_name(gname(p)))

    candidates = [p for p in places if "location" in p and is_medical(p)
                  # A hospital is not the clinic, even with a similar name ("KK Kuala Kangsar" -> the hospital).
                  and not ("hospital" in _words(gname(p)) and "hospital" not in _words(ours))
                  and distinctive_words_agree(ours, gname(p))]
    scored = sorted(((similarity(p), p) for p in candidates), key=lambda x: -x[0])
    place = next((p for score, p in scored if score >= MIN_NAME_SIMILARITY), None)
    if place is None:
        place = next((p for score, p in scored
                      if score >= MIN_SIMILARITY_IF_SAME_PLACE and dist(p) <= SAME_BUILDING_KM), None)
    check = ClinicPlaceCheck(clinic_code=row.clinic_code, status="not_found",
                             checked_at=datetime.now(timezone.utc), check_version=CHECK_VERSION)
    if place is None:
        return check
    loc = place["location"]
    check.google_place_id = place.get("id")
    check.google_name = gname(place)
    check.google_address = place.get("formattedAddress")
    check.google_types = place.get("types")
    check.google_latitude, check.google_longitude = loc.get("latitude"), loc.get("longitude")
    check.business_status = place.get("businessStatus")
    check.opening_periods = (place.get("regularOpeningHours") or {}).get("periods") or None
    if is_not_gp(place):
        check.status = "not_gp"
        return check
    branch = other_branch(row, check.google_name)
    agrees = address_agrees(row, check.google_address)
    if dist(place) <= MATCH_MAX_KM:
        check.status = "match" if agrees or not branch else "uncertain"
    else:
        check.status = "mismatch" if agrees and not branch else "uncertain"
    return check


def needs_lookup(row: ClinicRow, now: datetime) -> bool:
    if row.checked_at is None or row.check_version != CHECK_VERSION:
        return True
    checked = row.checked_at if row.checked_at.tzinfo else row.checked_at.replace(tzinfo=timezone.utc)
    return now - checked > RECHECK_AFTER


def search_query(row: ClinicRow) -> str:
    return ", ".join(p for p in (expand_name(row.name), row.address, row.postcode, row.city, row.state) if p)


def lookup_and_store(row: ClinicRow, api_key: str, timeout: float = 15) -> ClinicPlaceCheck:
    """One Places call for one clinic; stores the result and updates the (cached) row in place."""
    places = search_places(search_query(row), api_key, field_mask=CLINIC_FIELDS,
                           near=(row.db_latitude, row.db_longitude), timeout=timeout)
    check = check_clinic(row, places)
    factory = get_session_factory()
    if factory is not None:
        with factory() as session:
            session.merge(check)
            session.commit()
    row.apply_check(check)
    return check


def _background_lookup(row: ClinicRow, api_key: str, timeout: float) -> None:
    global _failed_at
    try:
        lookup_and_store(row, api_key, timeout)
    except Exception as e:
        detail = e.response.text[:200] if isinstance(e, httpx.HTTPStatusError) else str(e)
        logger.warning(f"[clinic-hours] Places lookup failed for {row.clinic_code}, "
                       f"skipping Google for {FAILURE_BACKOFF_SECONDS}s: {detail}")
        _failed_at = time.monotonic()
    finally:
        with _in_flight_lock:
            _in_flight.discard(row.clinic_code)


def refresh_hours(rows: Sequence[ClinicRow], now: Optional[datetime] = None,
                  limit: int = LOOKUPS_PER_ROUND) -> int:
    """Looks up the first `limit` rows (pass them nearest first) never checked, or checked over RECHECK_AFTER ago
    or under older rules, in parallel within the timeout. Returns how many lookups were started.

    Lookups still running at the timeout finish in the background and are stored for the next request.
    """
    s = get_settings()
    if not s.CLINIC_HOURS_LOOKUP or not s.GOOGLE_MAPS_API_KEY:
        return 0
    if _failed_at is not None and time.monotonic() - _failed_at < FAILURE_BACKOFF_SECONDS:
        return 0
    now = now or datetime.now(timezone.utc)
    todo = []
    with _in_flight_lock:
        for r in rows:
            if len(todo) >= limit:
                break
            if r.clinic_code not in _in_flight and needs_lookup(r, now):
                _in_flight.add(r.clinic_code)
                todo.append(r)
    if not todo:
        return 0
    futures = [_executor.submit(_background_lookup, r, s.GOOGLE_MAPS_API_KEY, s.CLINIC_HOURS_TIMEOUT_SECONDS * 3)
               for r in todo]
    wait(futures, timeout=s.CLINIC_HOURS_TIMEOUT_SECONDS)
    return len(todo)


def stored_hours(rows: Sequence[ClinicRow], now: Optional[datetime] = None) -> Dict[str, str]:
    """clinic_code -> "open" | "closed" | "unknown" from stored checks only, or "gone" when Google lists the
    clinic as closed (permanently or temporarily), or "excluded" when it is not a walk-in GP."""
    now = now or datetime.now(timezone.utc)
    result = {}
    for r in rows:
        if not r.routable:
            result[r.clinic_code] = "excluded"
        elif r.business_status in ("CLOSED_PERMANENTLY", "CLOSED_TEMPORARILY"):
            result[r.clinic_code] = "gone"
        else:
            result[r.clinic_code] = open_status(r.opening_periods, now)
    return result


def hours_for(rows: Sequence[ClinicRow], now: Optional[datetime] = None) -> Dict[str, str]:
    """Statuses (see stored_hours) for every row, after Google lookups for the nearest unchecked ones.

    rows must be nearest first. A second round of lookups runs only when nothing is confirmed open.
    """
    now = now or datetime.now(timezone.utc)
    result = stored_hours(rows, now)
    for _ in range(LOOKUP_ROUNDS):
        if not refresh_hours(rows, now):
            break
        result = stored_hours(rows, now)
        if "open" in result.values():
            break
    return result
