from datetime import datetime, timezone
from sqlalchemy import JSON, Column, DateTime, Float, Integer, Text
from app.core.database import Base


def _utcnow():
    return datetime.now(timezone.utc)


class ClinicPlaceCheck(Base):
    """Google Places result for a clinic: its place and weekly opening hours (clinic_data is never modified).

    Written lazily by routing (services/clinic_hours_service.py) and by scripts/check_clinic_hours.py.
    status: match (same place, near the DB coordinate) | mismatch (same place by name and postcode/address, but
    the DB coordinate is wrong: Google's is used) | uncertain (maybe another branch; not used) | not_gp (Google
    lists it as a dentist, lab, skin clinic…: excluded from routing) | not_found.
    Hours and place id are used only on match / mismatch, and only from a check of the current check_version.
    opening_periods is Google's regularOpeningHours.periods (local time), or None when Google has none.
    """
    __tablename__ = "clinic_place_check"

    clinic_code = Column(Text, primary_key=True)
    status = Column(Text, nullable=False)
    google_place_id = Column(Text, nullable=True)
    google_name = Column(Text, nullable=True)
    google_latitude = Column(Float, nullable=True)
    google_longitude = Column(Float, nullable=True)
    business_status = Column(Text, nullable=True)
    opening_periods = Column(JSON, nullable=True)
    google_address = Column(Text, nullable=True)
    google_types = Column(JSON, nullable=True)
    check_version = Column(Integer, nullable=True)  # older checks are redone when the clinic is next shortlisted
    checked_at = Column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)
