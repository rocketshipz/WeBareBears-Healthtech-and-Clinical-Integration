from sqlalchemy import Column, Float, Text
from app.core.database import Base


class HospitalDirectory(Base):
    """The canonical hospital registry already present in Supabase."""
    __tablename__ = 'hospital_data'
    hospital_id = Column(Text, primary_key=True)
    hospital_code = Column(Text)
    hospital_name = Column(Text)
    hospital_type = Column(Text)
    hospital_category = Column(Text)
    address = Column(Text)
    city = Column(Text)
    state = Column(Text)
    phone = Column(Text)
    latitude = Column(Float)
    longitude = Column(Float)
