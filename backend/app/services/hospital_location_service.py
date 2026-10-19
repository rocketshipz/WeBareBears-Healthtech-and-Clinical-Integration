import logging
import re
import time
from difflib import SequenceMatcher
from typing import List, Optional, Sequence

import httpx
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.location_detector import calculate_haversine_distance, is_valid_coordinates
from app.models.hospital_directory import HospitalDirectory
from app.models.hospital_location_check import HospitalLocationCheck

logger = logging.getLogger(__name__)

PLACES_SEARCH_URL = "https://places.googleapis.com/v1/places:searchText"
MIN_NAME_SIMILARITY = 0.6  # to accept a Google result as this hospital at all
MIN_SIMILARITY_TO_RELOCATE = 0.8  # to replace the DB coordinate on a mismatch; below = "uncertain"
MIN_SIMILARITY_IF_SAME_PLACE = 0.3  # enough when Google's location agrees with the DB (within the threshold)
REQUEST_INTERVAL_SECONDS = 0.2  # ~5 calls per second

_COMPANY = re.compile(r"\b(sdn|bhd|berhad)\b")
# Words too generic to identify a hospital on their own.
_GENERIC = {"the", "hospital", "hospitals", "hosp", "medical", "centre", "center", "specialist", "pusat",
            "perubatan", "pakar", "group", "clinic", "klinik"}
# Words that, added by Google, point to another branch or building: "KPJ Pasir Gudang" is not
# "Hospital Pasir Gudang", "Queen Elizabeth Hospital II" is not "Queen Elizabeth".
_BRANCH_MARKERS = {"kpj", "columbia", "pantai", "sunway", "gleneagles", "kpmc", "mahkota", "tmc",
                   "i", "ii", "iii", "2", "3", "phase", "fasa", "unit", "annex", "wing"}
_PARENTHESES = re.compile(r"\(.*?\)")


def normalise_name(name: str) -> str:
    name = re.sub(r"[^a-z0-9 ]", " ", (name or "").lower())
    return " ".join(_COMPANY.sub(" ", name).split())


def name_similarity(a: str, b: str) -> float:
    """0-1 similarity of two hospital names, ignoring case, punctuation and company suffixes."""
    na, nb = normalise_name(a), normalise_name(b)
    if not na or not nb:
        return 0.0
    if na == nb:
        return 1.0
    shorter, longer = sorted((na.split(), nb.split()), key=len)
    # Every word of one name inside the other is a match, but only for a distinctive name:
    # "kpj hospital" would match every KPJ branch, while "klsmc hospital" is specific enough.
    key_words = [w for w in shorter if w not in _GENERIC]
    distinctive = len(key_words) >= 2 or any(len(w) >= 4 for w in key_words)
    if distinctive and set(shorter) <= set(longer):
        return 1.0
    return SequenceMatcher(None, na, nb).ratio()


def other_branch(db_name: str, google_name: str) -> bool:
    """True when Google's name adds a chain brand or branch marker the DB name lacks (text in brackets ignored)."""
    extra = set(normalise_name(_PARENTHESES.sub(" ", google_name or "")).split()) - set(normalise_name(db_name).split())
    return bool(extra & _BRANCH_MARKERS)


def pick_match(name: str, places: Sequence[dict], min_score: float = MIN_NAME_SIMILARITY) -> Optional[dict]:
    """The Places result whose name best matches the hospital, or None if none is similar enough."""
    best, best_score = None, min_score
    for place in places:
        if "location" not in place:
            continue
        score = name_similarity(name, (place.get("displayName") or {}).get("text", ""))
        if score >= best_score:
            best, best_score = place, score
    return best


def classify(distance_km: Optional[float], threshold_km: float) -> str:
    if distance_km is None:
        return "not_found"
    return "mismatch" if distance_km > threshold_km else "match"


def search_places(query: str, api_key: str) -> List[dict]:
    resp = httpx.post(
        PLACES_SEARCH_URL,
        json={"textQuery": query, "regionCode": "MY", "maxResultCount": 3},
        headers={"X-Goog-Api-Key": api_key,
                 "X-Goog-FieldMask": "places.id,places.displayName,places.location,places.formattedAddress"},
        timeout=15,
    )
    resp.raise_for_status()
    return resp.json().get("places", [])


def check_hospital(hospital: HospitalDirectory, places: Sequence[dict], threshold_km: float) -> HospitalLocationCheck:
    """Compares one hospital's DB coordinate with the best-matching Google place."""
    has_coords = (hospital.latitude is not None and hospital.longitude is not None
                  and is_valid_coordinates(hospital.latitude, hospital.longitude))
    place = pick_match(hospital.hospital_name, places)
    if place is None and has_coords:
        # A weaker name match still confirms the hospital when Google puts it where the DB does.
        place = next((p for p in places if "location" in p
                      and name_similarity(hospital.hospital_name, (p.get("displayName") or {}).get("text", ""))
                      >= MIN_SIMILARITY_IF_SAME_PLACE
                      and calculate_haversine_distance(hospital.latitude, hospital.longitude,
                                                       p["location"]["latitude"], p["location"]["longitude"])
                      <= threshold_km), None)
    check = HospitalLocationCheck(hospital_id=hospital.hospital_id, status="not_found")
    if place is None:
        return check
    loc = place["location"]
    check.google_place_id = place.get("id")
    check.google_name = (place.get("displayName") or {}).get("text")
    check.google_latitude, check.google_longitude = loc.get("latitude"), loc.get("longitude")
    distance = None
    if has_coords:
        distance = round(calculate_haversine_distance(
            hospital.latitude, hospital.longitude, check.google_latitude, check.google_longitude), 3)
    check.distance_km = distance
    # No usable DB coordinate but Google found the place: use Google's.
    check.status = classify(distance, threshold_km) if distance is not None else "mismatch"
    # Only move a hospital when the names clearly agree; otherwise leave the DB coordinate for review.
    if check.status == "mismatch" and (
            name_similarity(hospital.hospital_name, check.google_name) < MIN_SIMILARITY_TO_RELOCATE
            or other_branch(hospital.hospital_name, check.google_name)):
        check.status = "uncertain"
    return check


def reclassify(session: Session) -> List[HospitalLocationCheck]:
    """Re-applies the current matching rules to stored results (no Google calls), e.g. after changing them."""
    threshold = get_settings().HOSPITAL_LOCATION_MISMATCH_KM
    checks = []
    for check in session.query(HospitalLocationCheck).filter(HospitalLocationCheck.google_name.isnot(None)):
        hospital = session.get(HospitalDirectory, check.hospital_id)
        if hospital is None:
            continue
        place = {"id": check.google_place_id, "displayName": {"text": check.google_name},
                 "location": {"latitude": check.google_latitude, "longitude": check.google_longitude}}
        new = check_hospital(hospital, [place], threshold)
        # The stored Google candidate is kept even when rejected, so rules can be re-applied later.
        check.status = new.status
        if new.distance_km is not None:
            check.distance_km = new.distance_km
        checks.append(check)
    session.commit()
    return checks


def verify_locations(session: Session, only_new: bool = False, limit: Optional[int] = None) -> List[HospitalLocationCheck]:
    """Looks up every hospital on Google Places and stores the comparison. Returns the checks written."""
    s = get_settings()
    if not s.GOOGLE_MAPS_API_KEY:
        raise RuntimeError("GOOGLE_MAPS_API_KEY is not set in backend/.env")
    HospitalLocationCheck.__table__.create(session.get_bind(), checkfirst=True)
    query = session.query(HospitalDirectory).order_by(HospitalDirectory.hospital_id)
    if only_new:  # unchecked hospitals, plus earlier not_found ones (retried)
        done = {h for (h,) in session.query(HospitalLocationCheck.hospital_id)
                .filter(HospitalLocationCheck.status != "not_found")}
        hospitals = [h for h in query if h.hospital_id not in done]
    else:
        hospitals = query.all()
    hospitals = hospitals[:limit] if limit else hospitals

    written = []
    for i, hospital in enumerate(hospitals, 1):
        text = ", ".join(p for p in (hospital.hospital_name, hospital.address, hospital.city, hospital.state) if p)
        try:
            places = search_places(text, s.GOOGLE_MAPS_API_KEY)
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429:
                # Daily quota: results so far are saved; continue tomorrow with --only-new.
                logger.warning(f"[locations] Places quota reached after {len(written)}; re-run with --only-new.")
                break
            raise RuntimeError(f"Places API error: {e.response.text[:300]}") from e
        except Exception as e:
            logger.warning(f"[locations] {hospital.hospital_id}: lookup failed ({e}); skipped.")
            continue
        check = session.merge(check_hospital(hospital, places, s.HOSPITAL_LOCATION_MISMATCH_KM))
        session.commit()
        written.append(check)
        if i % 25 == 0:
            logger.info(f"[locations] {i}/{len(hospitals)} checked.")
        time.sleep(REQUEST_INTERVAL_SECONDS)
    return written
