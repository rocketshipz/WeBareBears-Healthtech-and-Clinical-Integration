import logging
from datetime import datetime, timezone
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc

from app.models.user import User, EmailVerificationCode
from app.repositories.base import BaseRepository

logger = logging.getLogger(__name__)


class UserRepository(BaseRepository[User, str]):
    """Repository handling database operations for User and verification codes in PostgreSQL."""

    def __init__(self, session: Session):
        self.session = session

    def get_by_id(self, entity_id: str) -> Optional[User]:
        """Retrieve user by ID."""
        return self.session.query(User).filter(User.id == entity_id).first()

    def get_by_email(self, email: str) -> Optional[User]:
        """Retrieve user by email (case-insensitive)."""
        return self.session.query(User).filter(
            User.email.ilike(email.strip().lower())
        ).first()

    def get_by_phone(self, phone: str) -> Optional[User]:
        """Retrieve user by phone number."""
        return self.session.query(User).filter(
            User.phone == phone.strip()
        ).first()

    def get_by_ic(self, ic: str) -> Optional[User]:
        """Retrieve user by IC number."""
        clean_ic = ic.strip().replace("-", "")
        # Check both with and without hyphen formatting
        return self.session.query(User).filter(
            or_(
                User.ic == ic.strip(),
                User.ic == clean_ic,
            )
        ).first()

    def get_by_identifier(self, identifier: str) -> Optional[User]:
        """Find user by email, phone, or IC."""
        clean_ident = identifier.strip()
        clean_ic = clean_ident.replace("-", "")

        return self.session.query(User).filter(
            or_(
                User.email.ilike(clean_ident.lower()),
                User.phone == clean_ident,
                User.ic == clean_ident,
                User.ic == clean_ic,
            )
        ).first()

    def create(self, user: User) -> User:
        """Insert and commit a new user record."""
        self.session.add(user)
        self.session.commit()
        self.session.refresh(user)
        return user

    def list_all(self, limit: int = 100, offset: int = 0) -> List[User]:
        """List users with pagination."""
        return self.session.query(User).offset(offset).limit(limit).all()

    # =========================================================================
    # Verification Codes
    # =========================================================================

    def save_verification_code(
        self,
        email: str,
        code: str,
        expires_at: datetime,
    ) -> EmailVerificationCode:
        """Store a new 6-digit email verification code."""
        record = EmailVerificationCode(
            email=email.strip().lower(),
            code=code.strip(),
            expires_at=expires_at,
            attempts=0,
            verified=False,
        )
        self.session.add(record)
        self.session.commit()
        self.session.refresh(record)
        return record

    def get_latest_verification_code(self, email: str) -> Optional[EmailVerificationCode]:
        """Retrieve the most recently issued verification code for an email."""
        return (
            self.session.query(EmailVerificationCode)
            .filter(EmailVerificationCode.email == email.strip().lower())
            .order_by(desc(EmailVerificationCode.created_at))
            .first()
        )

    def mark_code_verified(self, code_id: int) -> None:
        """Mark a verification code entry as verified."""
        code_entry = self.session.query(EmailVerificationCode).filter(
            EmailVerificationCode.id == code_id
        ).first()
        if code_entry:
            code_entry.verified = True
            self.session.commit()

    def increment_attempts(self, code_id: int) -> int:
        """Increment failed attempts count for a verification code."""
        code_entry = self.session.query(EmailVerificationCode).filter(
            EmailVerificationCode.id == code_id
        ).first()
        if code_entry:
            code_entry.attempts += 1
            self.session.commit()
            return code_entry.attempts
        return 0

    def cleanup_codes_for_email(self, email: str) -> None:
        """Delete verification codes for an email after successful registration."""
        self.session.query(EmailVerificationCode).filter(
            EmailVerificationCode.email == email.strip().lower()
        ).delete(synchronize_session=False)
        self.session.commit()
