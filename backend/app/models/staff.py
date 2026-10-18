from sqlalchemy import BigInteger, Boolean, Column, DateTime, String, Text, func

from app.core.database import Base


def starter_password_hash():
    from app.services.auth_service import _hash_password
    return _hash_password('triagemy123')


class StaffAccount(Base):
    """Maps the existing staff_login table; does not modify its schema."""
    __tablename__ = "staff_login"

    id = Column(BigInteger, primary_key=True)
    staff_id = Column(Text, primary_key=True)
    hospital = Column(Text)
    hospital_id = Column(Text)
    name = Column(Text)
    email = Column(Text)
    role = Column(Text)
    department = Column(Text)
    password_hash = Column(Text, default=starter_password_hash)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime)
    last_login_at = Column(DateTime)
