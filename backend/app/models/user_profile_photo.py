from sqlalchemy import Column, ForeignKey, String, Text

from app.core.database import Base


class UserProfilePhoto(Base):
    """Separate table so existing demographics tables need no column migration."""
    __tablename__ = 'user_profile_photos'

    user_id = Column(String(50), ForeignKey('users.id', ondelete='CASCADE'), primary_key=True)
    photo_data_url = Column(Text, nullable=False)
