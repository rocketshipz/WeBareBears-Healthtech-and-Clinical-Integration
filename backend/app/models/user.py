from datetime import datetime, timezone
from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    DateTime,
    Integer,
    String,
    Text,
    func,
)
from app.core.database import Base


class User(Base):
    """User account entity stored in PostgreSQL."""
    __tablename__ = "users"

    id = Column(String(50), primary_key=True, index=True)
    ic = Column(Text, unique=True, index=True, nullable=False)
    phone = Column(Text, unique=True, index=True, nullable=False)
    email = Column(Text, unique=True, index=True, nullable=False)
    password_hash = Column(Text, nullable=False)
    name = Column(Text, nullable=True)
    is_verified = Column(Boolean, default=True, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )

    def to_dict(self):
        return {
            "id": self.id,
            "ic": self.ic,
            "phone": self.phone,
            "email": self.email,
            "name": self.name,
            "is_verified": self.is_verified,
            "created_at": self.created_at.isoformat() if self.created_at else None,
        }


class EmailVerificationCode(Base):
    """Temporary email verification code stored in PostgreSQL."""
    __tablename__ = "email_verification_codes"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    email = Column(Text, index=True, nullable=False)
    code = Column(String(6), nullable=False)
    expires_at = Column(DateTime(timezone=True), nullable=False)
    attempts = Column(Integer, default=0, nullable=False)
    verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        server_default=func.now(),
        nullable=False,
    )
