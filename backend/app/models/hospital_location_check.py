from datetime import datetime, timezone
from sqlalchemy import Column, DateTime, Float, Text
from app.core.database import Base


def _utcnow():
    return datetime.now(timezone.utc)


class HospitalLocationCheck(Base):
    """Google Places location of each hospital, compared with hospital_data (which is never modified).

    Written by scripts/verify_hospital_locations.py. status: match | mismatch | uncertain | not_found.
    Routing uses the Google coordinates only on a mismatch (names clearly agree). "uncertain" is a
    far-away Google result with a weaker name match: the DB coordinate is kept and it is listed for review.
    """
    __tablename__ = "hospital_location_check"

    hospital_id = Column(Text, primary_key=True)
    google_place_id = Column(Text, nullable=True)
    google_name = Column(Text, nullable=True)
    google_latitude = Column(Float, nullable=True)
    google_longitude = Column(Float, nullable=True)
    distance_km = Column(Float, nullable=True)
    status = Column(Text, nullable=False)
    checked_at = Column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=False)
