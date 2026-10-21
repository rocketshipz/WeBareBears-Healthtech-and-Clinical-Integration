import re
from datetime import date
from typing import Optional, Dict, Any, Literal
from pydantic import BaseModel, Field, field_validator, model_validator

EMAIL_REGEX = re.compile(r"^[a-zA-Z0-9!#$%&'*+/=?^_`{|}~.-]+@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$")


def valid_email(value: str) -> str:
    clean = value.strip().lower()
    local = clean.split('@')[0]
    if (len(clean) > 254 or len(local) > 64 or local.startswith('.')
            or local.endswith('.') or '..' in local or not EMAIL_REGEX.fullmatch(clean)):
        raise ValueError("Invalid email format")
    return clean


def normalize_phone(value: str) -> str:
    clean = re.sub(r"[ ()-]", "", value.strip())
    if clean.startswith('01'):
        clean = '+6' + clean
    elif clean.startswith('60'):
        clean = '+' + clean
    if not re.fullmatch(r"\+[1-9][0-9]{7,14}", clean):
        raise ValueError("Enter a valid phone number with country code, e.g. +60123456789")
    if clean.startswith('+60') and not re.fullmatch(r"\+601[02-9][0-9]{7}|\+6011[0-9]{8}", clean):
        raise ValueError("Enter a valid Malaysian mobile number")
    return clean


def strong_password(value: str) -> str:
    if not (len(value) >= 8 and re.search(r'[A-Z]', value) and re.search(r'[a-z]', value)
            and re.search(r'[0-9]', value) and re.search(r'[^a-zA-Z0-9\s]', value)):
        raise ValueError('Password must have at least 8 characters, uppercase, lowercase, a number and a symbol')
    return value


class SendCodeRequest(BaseModel):
    """Request schema for sending a email verification code."""
    email: str = Field(..., description="User's email address")
    phone: str

    _phone = field_validator('phone')(normalize_phone)

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        return valid_email(v)


class SendCodeResponse(BaseModel):
    """Response schema after sending verification code."""
    email: str
    message: str
    expires_in_seconds: int = 300
    debug_code: Optional[str] = Field(
        None,
        description="Verification code displayed in development/test environment for easy preview."
    )


class VerifyCodeRequest(BaseModel):
    """Request schema to verify the 6-digit email code."""
    email: str = Field(..., description="Email associated with the signup")
    phone: str

    _phone = field_validator('phone')(normalize_phone)
    code: str = Field(..., pattern=r"^[0-9]{6}$", description="6-digit verification code")

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        return valid_email(v)


class VerifyCodeResponse(BaseModel):
    """Response schema for code verification."""
    verified: bool
    email: str
    message: str


class RegisterRequest(BaseModel):
    """Request schema for user registration."""
    ic: str = Field(..., min_length=6, description="National Identity Card number (IC)")
    phone: str = Field(..., min_length=8, description="Phone number")
    email: str = Field(..., description="Contact email address")
    password: str = Field(..., min_length=8, description="Password (at least 8 characters)")
    name: str = Field(..., min_length=1, description="Full name")
    sex_at_birth: Literal["male", "female", "intersex"]
    nationality: str = Field(..., min_length=1)
    date_of_birth: Optional[date] = None
    code: Optional[str] = Field(None, description="6-digit verification code if verifying during registration")

    _phone = field_validator('phone')(normalize_phone)

    _password = field_validator('password')(strong_password)

    @model_validator(mode="after")
    def validate_birth_date(self):
        if self.nationality != "Malaysia" and self.date_of_birth is None:
            raise ValueError("Date of birth is required for non-Malaysian registration")
        if self.date_of_birth is not None and self.date_of_birth > date.today():
            raise ValueError("Date of birth cannot be in the future")
        return self

    @field_validator("name", "nationality")
    @classmethod
    def validate_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("This field is required")
        return value

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        return valid_email(v)


class LoginRequest(BaseModel):
    """Request schema for user login."""
    identifier: str = Field(..., description="Email, Phone number, or IC number")
    password: str = Field(..., min_length=1, description="Account password")


class ForgotPasswordRequest(BaseModel):
    """Request a password reset TAC for the account registered to this email."""
    email: str

    _email = field_validator('email')(valid_email)


class VerifyResetCodeRequest(ForgotPasswordRequest):
    code: str = Field(..., pattern=r"^[0-9]{6}$", description="6-digit reset code")


class ResetPasswordRequest(VerifyResetCodeRequest):
    new_password: str = Field(..., min_length=8)

    _password = field_validator('new_password')(strong_password)


class UserProfile(BaseModel):
    """Public user profile information."""
    id: str
    ic: str
    phone: str
    email: str
    name: Optional[str] = None
    created_at: str


class AuthTokenResponse(BaseModel):
    """Authentication token response on login/registration."""
    token: str
    token_type: str = "bearer"
    user: Dict[str, Any]
