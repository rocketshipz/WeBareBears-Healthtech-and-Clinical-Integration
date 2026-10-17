import hashlib
import logging
import os
import secrets
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Generator, Optional

from sqlalchemy.orm import Session

from app.core.database import Base, get_engine, get_session_factory
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.auth import (
    AuthTokenResponse,
    LoginRequest,
    RegisterRequest,
    SendCodeResponse,
    VerifyCodeResponse,
)

logger = logging.getLogger(__name__)


def _hash_password(password: str) -> str:
    """Hash a password using PBKDF2-HMAC-SHA256 with a cryptographically secure random salt."""
    salt = os.urandom(16)
    key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 100_000)
    return salt.hex() + ":" + key.hex()


def _verify_password(password: str, hashed: str) -> bool:
    """Verify a plain password against the stored salt:key string."""
    try:
        salt_hex, key_hex = hashed.split(":")
        salt = bytes.fromhex(salt_hex)
        key = hashlib.pbkdf2_hmac("sha256", password.encode("utf-8"), salt, 100_000)
        return secrets.compare_digest(key.hex(), key_hex)
    except Exception:
        return False


class AuthService:
    """Service handling email verification codes, user registration, and authentication in PostgreSQL."""

    def __init__(self):
        # In-memory store for active login sessions: token -> user_dict
        self._active_sessions: Dict[str, Dict[str, Any]] = {}
        
        # Ensure database tables exist
        self._init_db()

    def _init_db(self) -> None:
        """Create PostgreSQL tables if they don't exist yet."""
        try:
            engine = get_engine()
            if engine is not None:
                Base.metadata.create_all(bind=engine, checkfirst=True)
                logger.info("PostgreSQL auth tables verified.")
        except Exception as e:
            logger.error(f"Failed to initialize PostgreSQL auth tables: {e}")

    @contextmanager
    def _get_db(self) -> Generator[Session, None, None]:
        """Provides a managed SQLAlchemy database session."""
        session_factory = get_session_factory()
        if session_factory is None:
            raise RuntimeError("Database connection is not available.")
        session: Session = session_factory()
        try:
            yield session
        except Exception:
            session.rollback()
            raise
        finally:
            session.close()

    def send_verification_code(self, email: str) -> SendCodeResponse:
        """Generate and store a 6-digit verification code in PostgreSQL."""
        norm_email = email.strip().lower()

        # Generate 6-digit numeric verification code
        code = f"{secrets.randbelow(900000) + 100000}"
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=5)

        with self._get_db() as session:
            repo = UserRepository(session)
            repo.save_verification_code(
                email=norm_email,
                code=code,
                expires_at=expires_at,
            )

        logger.info("=" * 60)
        logger.info(f"📧 [EMAIL VERIFICATION CODE] Sent to: {norm_email}")
        logger.info(f"🔑 6-Digit Code: {code}")
        logger.info(f"⏰ Expires at: {expires_at.isoformat()}")
        logger.info("=" * 60)

        return SendCodeResponse(
            email=norm_email,
            message=f"6-digit verification code sent to {norm_email}.",
            expires_in_seconds=300,
            debug_code=code,
        )

    def verify_code(self, email: str, code: str) -> VerifyCodeResponse:
        """Verify the 6-digit code against the recorded code in PostgreSQL."""
        norm_email = email.strip().lower()

        with self._get_db() as session:
            repo = UserRepository(session)
            entry = repo.get_latest_verification_code(norm_email)

            if not entry:
                return VerifyCodeResponse(
                    verified=False,
                    email=norm_email,
                    message="No verification code found. Please request a new code.",
                )

            # Check expiration
            now = datetime.now(timezone.utc)
            if now > entry.expires_at:
                return VerifyCodeResponse(
                    verified=False,
                    email=norm_email,
                    message="Verification code has expired. Please request a new code.",
                )

            # Check maximum attempts
            if entry.attempts >= 5:
                return VerifyCodeResponse(
                    verified=False,
                    email=norm_email,
                    message="Too many failed attempts. Please request a new code.",
                )

            if not secrets.compare_digest(entry.code, code.strip()):
                repo.increment_attempts(entry.id)
                return VerifyCodeResponse(
                    verified=False,
                    email=norm_email,
                    message="Invalid verification code. Please check your email and try again.",
                )

            repo.mark_code_verified(entry.id)
            return VerifyCodeResponse(
                verified=True,
                email=norm_email,
                message="Email successfully verified.",
            )

    def register(self, request: RegisterRequest) -> AuthTokenResponse:
        """Register a new patient account in PostgreSQL after email verification."""
        norm_email = request.email.strip().lower()
        clean_ic = request.ic.strip()
        clean_phone = request.phone.strip()

        with self._get_db() as session:
            repo = UserRepository(session)

            # Verify email code
            if request.code:
                entry = repo.get_latest_verification_code(norm_email)
                if (
                    not entry
                    or not secrets.compare_digest(entry.code, request.code.strip())
                    or datetime.now(timezone.utc) > entry.expires_at
                ):
                    raise ValueError("Invalid or expired verification code.")
            else:
                entry = repo.get_latest_verification_code(norm_email)
                if not entry or not entry.verified:
                    raise ValueError(
                        "Email has not been verified. Please verify your email first."
                    )

            # Check duplicate email
            if repo.get_by_email(norm_email):
                raise ValueError(f"An account with email {norm_email} already exists.")

            # Check duplicate IC
            if repo.get_by_ic(clean_ic):
                raise ValueError("An account with this IC number already exists.")

            # Check duplicate phone
            if repo.get_by_phone(clean_phone):
                raise ValueError("An account with this phone number already exists.")

            user_id = f"usr_{secrets.token_hex(6)}"
            hashed_password = _hash_password(request.password)

            new_user = User(
                id=user_id,
                ic=clean_ic,
                phone=clean_phone,
                email=norm_email,
                name=request.name.strip() if request.name else None,
                password_hash=hashed_password,
                is_verified=True,
            )

            created_user = repo.create(new_user)
            public_user = created_user.to_dict()

            # Clean up verification codes for this email
            repo.cleanup_codes_for_email(norm_email)

            # Generate auth session token
            token = secrets.token_urlsafe(32)
            self._active_sessions[token] = public_user

            logger.info(
                f"✅ User registered successfully in PostgreSQL: {norm_email} (ID: {user_id})"
            )

            return AuthTokenResponse(
                token=token,
                token_type="bearer",
                user=public_user,
            )

    def login(self, request: LoginRequest) -> AuthTokenResponse:
        """Authenticate user from PostgreSQL by email, phone, or IC and password."""
        with self._get_db() as session:
            repo = UserRepository(session)
            matched_user = repo.get_by_identifier(request.identifier)

            if not matched_user:
                raise ValueError(
                    "Invalid credentials. Please check your details and try again."
                )

            if not _verify_password(request.password, matched_user.password_hash):
                raise ValueError("Invalid credentials. Incorrect password.")

            token = secrets.token_urlsafe(32)
            public_user = matched_user.to_dict()
            self._active_sessions[token] = public_user

            logger.info(
                f"🔓 User authenticated successfully from PostgreSQL: {matched_user.email}"
            )

            return AuthTokenResponse(
                token=token,
                token_type="bearer",
                user=public_user,
            )

    def get_user_by_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Retrieve user info associated with an active session token."""
        return self._active_sessions.get(token)

    def logout(self, token: str) -> bool:
        """Invalidate user session token."""
        if token in self._active_sessions:
            del self._active_sessions[token]
            return True
        return False
