from sqlalchemy import BigInteger, Column, DateTime, Text
from app.core.database import Base


class ClinicDirectory(Base):
    """The clinic registry already present in Supabase (read-only). latitude/longitude are stored as text."""
    __tablename__ = 'clinic_data'
    clinic_code = Column(Text, primary_key=True)
    clinic_name = Column(Text)
    clinic_category = Column(Text)
    clinic_type = Column(Text)
    state = Column(Text)
    district = Column(Text)
    city = Column(Text)
    postcode = Column(BigInteger)
    latitude = Column(Text)
    longitude = Column(Text)
    phone = Column(Text)
    address = Column(Text)
    source = Column(Text)
    category_basis = Column(Text)
    last_checked_utc = Column(DateTime(timezone=True))
