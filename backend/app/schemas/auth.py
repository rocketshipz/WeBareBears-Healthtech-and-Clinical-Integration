import re
from typing import Optional, Dict, Any
from pydantic import BaseModel, Field, field_validator

EMAIL_REGEX = re.compile(r"^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$")


class SendCodeRequest(BaseModel):
    """Request schema for sending an email verification code."""
    email: str = Field(..., description="User's email address")

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        clean = v.strip().lower()
        if not EMAIL_REGEX.match(clean):
            raise ValueError("Invalid email format")
        return clean


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
    email: str = Field(..., description="Email address the code was sent to")
    code: str = Field(..., min_length=6, max_length=6, description="6-digit verification code")

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        clean = v.strip().lower()
        if not EMAIL_REGEX.match(clean):
            raise ValueError("Invalid email format")
        return clean


class VerifyCodeResponse(BaseModel):
    """Response schema for code verification."""
    verified: bool
    email: str
    message: str


class RegisterRequest(BaseModel):
    """Request schema for user registration."""
    ic: str = Field(..., min_length=6, description="National Identity Card number (IC)")
    phone: str = Field(..., min_length=8, description="Phone number")
    email: str = Field(..., description="Verified email address")
    password: str = Field(..., min_length=8, description="Password (at least 8 characters)")
    name: Optional[str] = Field(None, description="Full name (optional)")
    code: Optional[str] = Field(None, description="6-digit verification code if verifying during registration")

    @field_validator("email")
    @classmethod
    def validate_email_format(cls, v: str) -> str:
        clean = v.strip().lower()
        if not EMAIL_REGEX.match(clean):
            raise ValueError("Invalid email format")
        return clean


class LoginRequest(BaseModel):
    """Request schema for user login."""
    identifier: str = Field(..., description="Email, Phone number, or IC number")
    password: str = Field(..., min_length=1, description="Account password")


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
