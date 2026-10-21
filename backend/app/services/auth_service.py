import hashlib
from app.core.config import get_settings
from app.schemas.auth import normalize_phone
from app.services.email_service import email_configured, send_tac_email
import logging
import os
import secrets
from contextlib import contextmanager
from datetime import date, datetime, timedelta, timezone
from typing import Any, Dict, Generator, Optional

from sqlalchemy.orm import Session

from app.core.database import Base, get_engine, get_session_factory
from app.models.user import User
from app.models.user_information import UserInformation
from app.models.user_profile_photo import UserProfilePhoto
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


def _as_utc(value: datetime) -> datetime:
    """Normalize timezone-naive SQLite timestamps to UTC."""
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


class AuthService:
    """Service handling Email verification codes, user registration, and authentication in PostgreSQL."""

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

    @staticmethod
    def _verification_key(email: str, phone: str) -> str:
        # Bind both contacts without changing the existing verification table.
        return 'email:' + hashlib.sha256(
            (email.strip().lower() + '\n' + normalize_phone(phone)).encode()
        ).hexdigest()

    @staticmethod
    def _tac_test_mode() -> bool:
        """True when TACs are returned as debug codes instead of emailed; raises if email is unusable."""
        settings = get_settings()
        test_mode = settings.TAC_DELIVERY == 'test' and settings.ENVIRONMENT in ('test', 'development')
        if not test_mode and settings.TAC_DELIVERY != 'email':
            raise ValueError('Unsupported TAC delivery mode. Configure email delivery.')
        if not test_mode and not email_configured():
            raise ValueError('Email verification is not configured. Please contact support.')
        return test_mode

    def send_verification_code(self, email: str, phone: str) -> SendCodeResponse:
        norm_email = email.strip().lower()
        phone = normalize_phone(phone)
        key = self._verification_key(norm_email, phone)
        test_mode = self._tac_test_mode()
        with self._get_db() as session:
            repo = UserRepository(session)
            previous = repo.get_latest_verification_code(key)
            if previous and datetime.now(timezone.utc) - _as_utc(previous.created_at) < timedelta(seconds=60):
                raise ValueError('Please wait 60 seconds before requesting another TAC.')
            code = f'{secrets.randbelow(900000) + 100000}'
            if not test_mode:
                send_tac_email(norm_email, code)
            repo.cleanup_codes_for_email(key)
            repo.save_verification_code(email=key, code=code,
                expires_at=datetime.now(timezone.utc) + timedelta(minutes=5))
        return SendCodeResponse(email=norm_email,
            message=('Test TAC generated; no email was sent.' if test_mode
                     else f'TAC sent to {norm_email}. Please check your inbox or spam folder.'),
            expires_in_seconds=300, debug_code=code if test_mode else None)

    @staticmethod
    def _check_code(repo: UserRepository, key: str, code: str) -> Optional[str]:
        """Validate a TAC for `key`, marking it verified. Returns an error message, or None on success."""
        entry = repo.get_latest_verification_code(key)
        if not entry:
            return "No verification code found. Please request a new code."
        if datetime.now(timezone.utc) > _as_utc(entry.expires_at):
            return "Verification code has expired. Please request a new code."
        if entry.attempts >= 5:
            return "Too many failed attempts. Please request a new code."
        if not secrets.compare_digest(entry.code, code.strip()):
            repo.increment_attempts(entry.id)
            return "Invalid verification code. Please check your email and try again."
        repo.mark_code_verified(entry.id)
        return None

    def verify_code(self, email: str, code: str, phone: str) -> VerifyCodeResponse:
        """Verify the 6-digit code against the recorded code in PostgreSQL."""
        norm_email = email.strip().lower()
        with self._get_db() as session:
            error = self._check_code(UserRepository(session), self._verification_key(norm_email, phone), code)
        return VerifyCodeResponse(verified=error is None, email=norm_email,
                                  message=error or "Email address successfully verified.")

    # =========================================================================
    # Password reset
    # =========================================================================

    @staticmethod
    def _reset_key(email: str) -> str:
        # Separate namespace from signup TACs so one can never be used as the other.
        return 'reset:' + hashlib.sha256(email.strip().lower().encode()).hexdigest()

    def request_password_reset(self, email: str) -> SendCodeResponse:
        """Email a reset TAC to the account registered with `email`.

        The response is the same whether or not an account exists, so the endpoint
        cannot be used to discover which emails are registered.
        """
        norm_email = email.strip().lower()
        test_mode = self._tac_test_mode()
        response = SendCodeResponse(email=norm_email, expires_in_seconds=300,
            message=f'If an account is registered to {norm_email}, a reset code has been sent to it.')
        with self._get_db() as session:
            repo = UserRepository(session)
            if repo.get_by_email(norm_email) is None:
                return response
            key = self._reset_key(norm_email)
            previous = repo.get_latest_verification_code(key)
            if previous and datetime.now(timezone.utc) - _as_utc(previous.created_at) < timedelta(seconds=60):
                return response  # the code already sent is still valid
            code = f'{secrets.randbelow(900000) + 100000}'
            if not test_mode:
                send_tac_email(norm_email, code, reset=True)
            repo.cleanup_codes_for_email(key)
            repo.save_verification_code(email=key, code=code,
                expires_at=datetime.now(timezone.utc) + timedelta(minutes=5))
        if test_mode:
            response.debug_code = code
        return response

    def verify_reset_code(self, email: str, code: str) -> VerifyCodeResponse:
        norm_email = email.strip().lower()
        with self._get_db() as session:
            error = self._check_code(UserRepository(session), self._reset_key(norm_email), code)
        return VerifyCodeResponse(verified=error is None, email=norm_email,
                                  message=error or "Code verified. You can now set a new password.")

    def reset_password(self, email: str, code: str, new_password: str) -> None:
        """Set a new password after checking the reset TAC, then sign the account out everywhere."""
        norm_email = email.strip().lower()
        key = self._reset_key(norm_email)
        with self._get_db() as session:
            repo = UserRepository(session)
            user = repo.get_by_email(norm_email)
            error = self._check_code(repo, key, code)
            if error or user is None:
                raise ValueError(error or "No verification code found. Please request a new code.")
            user.password_hash = _hash_password(new_password)
            session.commit()
            repo.cleanup_codes_for_email(key)
            user_id = user.id
        for token in [t for t, u in self._active_sessions.items() if u.get('id') == user_id]:
            del self._active_sessions[token]
        logger.info(f"Password reset for user {user_id}")

    def register(self, request: RegisterRequest) -> AuthTokenResponse:
        """Register a new patient account in PostgreSQL after email verification."""
        norm_email = request.email.strip().lower()
        clean_ic = request.ic.strip()
        clean_phone = request.phone.strip()

        with self._get_db() as session:
            repo = UserRepository(session)

            key = self._verification_key(norm_email, clean_phone)
            if request.code:
                result = self.verify_code(norm_email, request.code, clean_phone)
                if not result.verified:
                    raise ValueError(result.message)
            entry = repo.get_latest_verification_code(key)
            if (not entry or not entry.verified or entry.attempts >= 5
                    or datetime.now(timezone.utc) > _as_utc(entry.expires_at)):
                raise ValueError('Email address has not been verified or TAC has expired. Please request a new TAC.')

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

            # Save account and registration demographics in one transaction.
            if request.nationality == "Malaysia":
                digits = clean_ic.replace('-', '')
                try:
                    year = int(digits[:2])
                    today = date.today()
                    year += 1900 if year > today.year % 100 else 2000
                    birth_date = date(year, int(digits[2:4]), int(digits[4:6]))
                except (ValueError, TypeError):
                    raise ValueError("IC number must contain a valid date of birth.")
            else:
                birth_date = request.date_of_birth
            session.add(new_user)
            session.flush()
            session.add(UserInformation(
                user_id=user_id,
                date_of_birth=birth_date,
                sex_at_birth=request.sex_at_birth,
                nationality=request.nationality,
            ))
            session.commit()
            session.refresh(new_user)
            public_user = new_user.to_dict()
            public_user['sex_at_birth'] = request.sex_at_birth
            public_user['nationality'] = request.nationality
            public_user['date_of_birth'] = birth_date.isoformat()

            # Clean up verification codes for this email
            repo.cleanup_codes_for_email(key)

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
            information = session.get(UserInformation, matched_user.id)
            public_user['sex_at_birth'] = information.sex_at_birth if information else None
            public_user['nationality'] = information.nationality if information else None
            public_user['date_of_birth'] = information.date_of_birth.isoformat() if information else None
            self._active_sessions[token] = public_user

            logger.info(
                f"🔓 User authenticated successfully from PostgreSQL: {matched_user.email}"
            )

            return AuthTokenResponse(
                token=token,
                token_type="bearer",
                user=public_user,
            )

    def profile(self, token: str, changes=None) -> Dict[str, Any]:
        """Read or update the authenticated user's single information row."""
        identity = self.get_user_by_token(token)
        if not identity:
            raise PermissionError("Invalid or expired session token.")
        with self._get_db() as session:
            user = session.get(User, identity["id"])
            if user is None:
                raise PermissionError("Account no longer exists.")
            info = session.get(UserInformation, user.id)
            if info is None:
                raise ValueError("Account information is missing. Please contact support.")
            photo = session.get(UserProfilePhoto, user.id)
            if changes is not None:
                updates = changes.model_dump(exclude_unset=True)
                if 'photo_data_url' in updates:
                    image = updates.pop('photo_data_url')
                    if image is None:
                        if photo is not None:
                            session.delete(photo)
                        photo = None
                    elif photo is None:
                        photo = UserProfilePhoto(user_id=user.id, photo_data_url=image)
                        session.add(photo)
                    else:
                        photo.photo_data_url = image
                for key, value in updates.items():
                    setattr(info, key, value)
                if updates:
                    info.medical_info_updated_at = datetime.now(timezone.utc)
                session.commit()
                session.refresh(info)
            data = {column.name: getattr(info, column.name) for column in UserInformation.__table__.columns}
            data.update(name=user.name, ic=user.ic, age=info.age,
                        photo_data_url=photo.photo_data_url if photo else None)
            return data

    def get_user_by_token(self, token: str) -> Optional[Dict[str, Any]]:
        """Retrieve user info associated with an active session token."""
        return self._active_sessions.get(token)

    def logout(self, token: str) -> bool:
        """Invalidate user session token."""
        if token in self._active_sessions:
            del self._active_sessions[token]
            return True
        return False
