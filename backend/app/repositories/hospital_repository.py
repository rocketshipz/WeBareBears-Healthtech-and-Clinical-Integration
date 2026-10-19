import logging
from dataclasses import dataclass
from typing import Optional, List

from sqlalchemy import text

from app.core.config import get_settings
from app.repositories.base import BaseRepository
from app.models.hospital import Hospital
from app.models.hospital_directory import HospitalDirectory
from app.models.hospital_location_check import HospitalLocationCheck
from app.services.wait_time_service import _ident

logger = logging.getLogger(__name__)


@dataclass
class HospitalActivityRow:
    """A hospital_data row joined with its ED activity (activity fields are None when missing)."""
    hospital_id: str
    name: str
    category: Optional[str]
    address: Optional[str]
    phone: Optional[str]
    latitude: Optional[float]
    longitude: Optional[float]
    activity_level: Optional[str] = None
    available_ed_spaces: Optional[int] = None
    # From hospital_location_check (None until the location check has run for this hospital).
    location_status: Optional[str] = None
    google_place_id: Optional[str] = None
    google_latitude: Optional[float] = None
    google_longitude: Optional[float] = None

    def __post_init__(self):
        # Only a confirmed Google place is used for navigation; a rejected candidate is review data only.
        if self.location_status not in ("match", "mismatch"):
            self.google_place_id = None

    @property
    def uses_google_location(self) -> bool:
        """True when the DB coordinate disagreed with Google's, so Google's is used instead."""
        return (self.location_status == "mismatch"
                and self.google_latitude is not None and self.google_longitude is not None)

    @property
    def best_latitude(self) -> Optional[float]:
        return self.google_latitude if self.uses_google_location else self.latitude

    @property
    def best_longitude(self) -> Optional[float]:
        return self.google_longitude if self.uses_google_location else self.longitude


class HospitalRepository(BaseRepository[Hospital, str]):
    """Hospital data in Supabase/PostgreSQL: hospital_data plus the ED activity table (WAIT_LABEL_TABLE)."""

    def __init__(self, db_session=None):
        self.db_session = db_session

    def get_by_id(self, entity_id: str) -> Optional[Hospital]:
        """Placeholder for retrieving hospital by ID."""
        logger.info(f"[HospitalRepository] Fetching hospital {entity_id} (placeholder).")
        return None

    def list_all(self, limit: int = 100, offset: int = 0) -> List[Hospital]:
        """Placeholder for listing all registered hospitals."""
        return []

    def list_with_activity(self) -> List[HospitalActivityRow]:
        """Every hospital with its current ED activity level (outer join, so a missing activity row is None)."""
        if self.db_session is None:
            return []
        HospitalLocationCheck.__table__.create(self.db_session.get_bind(), checkfirst=True)
        s = get_settings()
        hospitals = _ident(HospitalDirectory.__tablename__)
        activity, key = _ident(s.WAIT_LABEL_TABLE), _ident(s.WAIT_LABEL_KEY_COL)
        label = _ident(s.WAIT_LABEL_COL)
        checks = _ident(HospitalLocationCheck.__tablename__)
        rows = self.db_session.execute(text(
            f"SELECT h.hospital_id, h.hospital_name, h.hospital_category, h.address, h.phone, "
            f"h.latitude, h.longitude, a.{label}, a.available_ed_spaces, "
            f"c.status, c.google_place_id, c.google_latitude, c.google_longitude "
            f"FROM {hospitals} h LEFT JOIN {activity} a ON a.{key} = h.hospital_id "
            f"LEFT JOIN {checks} c ON c.hospital_id = h.hospital_id"
        )).all()
        return [HospitalActivityRow(*row) for row in rows]
