from sqlalchemy import Column, Text
from app.core.database import Base


class HospitalDirectory(Base):
    """The canonical hospital registry already present in Supabase."""
    __tablename__ = 'hospital_data'
    hospital_id = Column(Text, primary_key=True)
    hospital_code = Column(Text)
    hospital_name = Column(Text)
