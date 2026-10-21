import logging
import re
import threading
import time
from dataclasses import dataclass
from datetime import datetime
from typing import List, Optional, Tuple

from sqlalchemy import inspect, text

from app.core.location_detector import is_valid_coordinates
from app.models.clinic_directory import ClinicDirectory
from app.models.clinic_place_check import ClinicPlaceCheck

logger = logging.getLogger(__name__)

GP_CATEGORIES = {"general_primary_care", "unknown"}  # "unknown" is mostly private GP "Klinik X"
RURAL_CATEGORY = "rural_clinic"  # Klinik Desa: nurse-run, used only when no GP-type clinic is available
CLINIC_CACHE_SECONDS = 3600
# Version of the Google matching rules in clinic_hours_service. A check made under older rules is not trusted
# (hours unknown, DB coordinate) and is redone the next time the clinic is shortlisted.
CHECK_VERSION = 2
USABLE_PLACE = {"match", "mismatch"}  # mismatch = same clinic, DB coordinate wrong (Google's is used)

# Names of specialist / non-walk-in clinics. Word boundaries, so "PERMATA" is not "MATA".
# "SURGERY" / "PEMBEDAHAN" are not here: in Malaysia "Klinik & Surgery" is a GP clinic.
# Malay and misspelt forms are included (ORTOPEDIK, OTOPAEDIC, PERGIGIAN, DIAGNOSTIK).
_SPECIALIST = re.compile(
    r"\b(PAKAR|SPECIALISTS?|EYE|MATA|SKIN|KULIT|DENTAL|GIGI|PERGIGIAN|AESTHETICS?|ESTETIK|FERTILITY|IVF|"
    r"DIALYSIS|DIALISIS|PLASTI[CK]|LASER|ORTHO\w*|ORTOP\w*|OTOPA?EDI\w*|CARDIO\w*|HEART|ONCO\w*|CANCER|"
    r"PSYCH\w*|SLIMMING|HAIR|PHYSIO\w*|RADIOLOG\w*|GASTRO\w*|DIAGNOS\w*|UROLOG\w*|NEURO\w*|ENT|OB-?GYN\w*|"
    r"O\s*&\s*G|GYNA?E\w*|SPINE|SURGICAL|ALLERGY|SCAN|LABORATORY|MAKMAL|OCCUPATIONAL)\b", re.IGNORECASE)


# Trailing MOH registration number in some names, e.g. "KLINIK TERRY LEE (A21401)".
_REGISTRATION = re.compile(r"\s*\(A\d+\)\s*$", re.IGNORECASE)


def display_name(name: str) -> str:
    return _REGISTRATION.sub("", name).strip() or name


def is_walk_in_gp(name: Optional[str]) -> bool:
    """False when the clinic name says it is a specialist or non-medical-walk-in centre."""
    return not _SPECIALIST.search(name or "")


def _coord(value) -> Optional[float]:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


@dataclass
class ClinicRow:
    """A routable clinic_data row, with its Google place check (None until checked)."""
    clinic_code: str
    name: str
    category: Optional[str]
    clinic_type: Optional[str]  # public | private
    address: Optional[str]
    phone: Optional[str]
    latitude: float  # Google's coordinate on a mismatch, otherwise clinic_data's
    longitude: float
    postcode: Optional[str] = None
    city: Optional[str] = None
    state: Optional[str] = None
    place_status: Optional[str] = None
    google_place_id: Optional[str] = None
    business_status: Optional[str] = None
    opening_periods: Optional[list] = None
    checked_at: Optional[datetime] = None
    check_version: Optional[int] = None
    db_latitude: Optional[float] = None
    db_longitude: Optional[float] = None

    def __post_init__(self):
        if self.db_latitude is None:
            self.db_latitude, self.db_longitude = self.latitude, self.longitude

    @property
    def is_rural(self) -> bool:
        return self.category == RURAL_CATEGORY

    @property
    def routable(self) -> bool:
        """False when Google lists the clinic as a dentist, lab, skin clinic and so on."""
        return self.place_status != "not_gp"

    def apply_check(self, check: ClinicPlaceCheck) -> None:
        self.place_status = check.status
        self.checked_at = check.checked_at
        self.check_version = check.check_version
        # Only a confirmed place, checked under the current rules, is used for navigation, hours and location.
        usable = check.status in USABLE_PLACE and check.check_version == CHECK_VERSION
        self.google_place_id = check.google_place_id if usable else None
        self.business_status = check.business_status if usable else None
        self.opening_periods = check.opening_periods if usable else None
        if (usable and check.status == "mismatch"
                and check.google_latitude is not None and check.google_longitude is not None):
            self.latitude, self.longitude = check.google_latitude, check.google_longitude
        else:
            self.latitude, self.longitude = self.db_latitude, self.db_longitude


_cache: Optional[Tuple[float, List[ClinicRow]]] = None
_lock = threading.Lock()


def clear_cache() -> None:
    global _cache
    _cache = None


class ClinicRepository:
    """Walk-in clinics from clinic_data, joined with clinic_place_check. Cached in memory for an hour."""

    def __init__(self, db_session=None):
        self.db_session = db_session

    def list_routable(self) -> List[ClinicRow]:
        """GP-type and Klinik Desa clinics with valid coordinates. Empty when clinic_data is missing."""
        global _cache
        if self.db_session is None:
            return []
        with _lock:
            if _cache and time.monotonic() - _cache[0] < CLINIC_CACHE_SECONDS:
                return _cache[1]
            try:
                rows = self._load()
            except Exception as e:
                self.db_session.rollback()
                logger.warning(f"[ClinicRepository] clinic_data unavailable, routing to hospitals only: {e}")
                return []
            _cache = (time.monotonic(), rows)
            logger.info(f"[ClinicRepository] Loaded {len(rows)} routable clinics.")
            return rows

    def _ensure_check_table(self) -> None:
        """Creates clinic_place_check, or adds columns introduced after it was first created."""
        bind = self.db_session.get_bind()
        ClinicPlaceCheck.__table__.create(bind, checkfirst=True)
        existing = {c["name"] for c in inspect(bind).get_columns(ClinicPlaceCheck.__tablename__)}
        missing = [c for c in ClinicPlaceCheck.__table__.columns if c.name not in existing]
        if missing:
            with bind.begin() as conn:
                for column in missing:
                    conn.execute(text(f'ALTER TABLE {ClinicPlaceCheck.__tablename__} ADD COLUMN '
                                      f'{column.name} {column.type.compile(dialect=bind.dialect)}'))
            logger.info(f"[ClinicRepository] Added clinic_place_check columns: {[c.name for c in missing]}")

    def _load(self) -> List[ClinicRow]:
        self._ensure_check_table()
        query = (self.db_session.query(ClinicDirectory, ClinicPlaceCheck)
                 .outerjoin(ClinicPlaceCheck, ClinicPlaceCheck.clinic_code == ClinicDirectory.clinic_code)
                 .filter(ClinicDirectory.clinic_category.in_(GP_CATEGORIES | {RURAL_CATEGORY})))
        rows = []
        for clinic, check in query:
            lat, lon = _coord(clinic.latitude), _coord(clinic.longitude)
            if lat is None or lon is None or not is_valid_coordinates(lat, lon):
                continue
            if not is_walk_in_gp(clinic.clinic_name):
                continue
            row = ClinicRow(clinic.clinic_code, display_name(clinic.clinic_name or clinic.clinic_code),
                            clinic.clinic_category, clinic.clinic_type, clinic.address, clinic.phone, lat, lon,
                            postcode=f"{clinic.postcode:05d}" if clinic.postcode else None,
                            city=clinic.city, state=clinic.state)
            if check is not None:
                row.apply_check(check)
            if row.routable:
                rows.append(row)
        return rows
