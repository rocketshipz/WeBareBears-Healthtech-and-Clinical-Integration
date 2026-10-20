import logging
from typing import Optional
from fastapi import APIRouter, Depends, Header, HTTPException, status

from app.schemas.common import APIResponse
from app.schemas.auth import (
    AuthTokenResponse,
    LoginRequest,
    RegisterRequest,
    SendCodeRequest,
    SendCodeResponse,
    VerifyCodeRequest,
    VerifyCodeResponse,
)
from app.services.auth_service import AuthService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["Authentication"])

# Singleton auth service instance
_auth_service = AuthService()


def get_auth_service() -> AuthService:
    return _auth_service


def get_optional_user(
    authorization: Optional[str] = Header(None),
    service: AuthService = Depends(get_auth_service),
) -> Optional[dict]:
    """The logged-in user for a `Bearer <token>` header, or None (no header, or unknown / expired token)."""
    if not authorization or not authorization.startswith("Bearer "):
        return None
    return service.get_user_by_token(authorization.split(" ", 1)[1])


def get_current_user(user: Optional[dict] = Depends(get_optional_user)) -> dict:
    """Like get_optional_user, but 401 when not logged in."""
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing, invalid or expired session token.",
        )
    return user


@router.post(
    "/send-code",
    response_model=APIResponse[SendCodeResponse],
    status_code=status.HTTP_200_OK,
    summary="Send 6-digit email verification code",
)
def send_verification_code(
    request: SendCodeRequest,
    service: AuthService = Depends(get_auth_service),
):
    """Sends a 6-digit verification code to the requested email address."""
    try:
        result = service.send_verification_code(request.email, request.phone)
        return APIResponse(
            success=True,
            data=result,
            message=result.message,
        )
    except Exception as e:
        logger.error(f"Error sending verification code: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )


@router.post(
    "/verify-code",
    response_model=APIResponse[VerifyCodeResponse],
    status_code=status.HTTP_200_OK,
    summary="Verify 6-digit email code",
)
async def verify_code(
    request: VerifyCodeRequest,
    service: AuthService = Depends(get_auth_service),
):
    """Validates the 6-digit code against the recorded code for the given email."""
    result = service.verify_code(request.email, request.code, request.phone)
    if not result.verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=result.message,
        )
    return APIResponse(
        success=True,
        data=result,
        message=result.message,
    )


@router.post(
    "/register",
    response_model=APIResponse[AuthTokenResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Register new user account",
)
async def register(
    request: RegisterRequest,
    service: AuthService = Depends(get_auth_service),
):
    """Creates a new patient account after email verification and returns an auth session."""
    try:
        result = service.register(request)
        return APIResponse(
            success=True,
            data=result,
            message="Account registered successfully.",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        logger.error(f"Unexpected registration error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed. Please try again later.",
        )


@router.post(
    "/login",
    response_model=APIResponse[AuthTokenResponse],
    status_code=status.HTTP_200_OK,
    summary="User login",
)
async def login(
    request: LoginRequest,
    service: AuthService = Depends(get_auth_service),
):
    """Authenticates a user via email, phone, or IC and password."""
    try:
        result = service.login(request)
        return APIResponse(
            success=True,
            data=result,
            message="Logged in successfully.",
        )
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )
    except Exception as e:
        logger.error(f"Unexpected login error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Login failed. Please try again later.",
        )


@router.post(
    "/logout",
    response_model=APIResponse[dict],
    status_code=status.HTTP_200_OK,
    summary="User logout",
)
async def logout(
    authorization: Optional[str] = Header(None),
    service: AuthService = Depends(get_auth_service),
):
    """Invalidates the provided bearer token session."""
    if authorization and authorization.startswith("Bearer "):
        token = authorization.split(" ")[1]
        service.logout(token)
    return APIResponse(
        success=True,
        data={"logged_out": True},
        message="Session logged out successfully.",
    )


@router.get(
    "/me",
    response_model=APIResponse[dict],
    status_code=status.HTTP_200_OK,
    summary="Get current user profile",
)
async def get_me(
    authorization: Optional[str] = Header(None),
    service: AuthService = Depends(get_auth_service),
):
    """Returns the profile of the currently logged in user."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or invalid Authorization header.",
        )
    token = authorization.split(" ")[1]
    user = service.get_user_by_token(token)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired session token.",
        )
    return APIResponse(
        success=True,
        data=user,
        message="User profile retrieved.",
    )


from app.schemas.profile import ProfileUpdate


def _profile_token(authorization: Optional[str]) -> str:
    if not authorization or not authorization.startswith("Bearer ") or not authorization[7:].strip():
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header.")
    return authorization[7:].strip()


@router.get("/profile", response_model=APIResponse[dict])
def read_profile(authorization: Optional[str] = Header(None), service: AuthService = Depends(get_auth_service)):
    try:
        return APIResponse(success=True, data=service.profile(_profile_token(authorization)))
    except PermissionError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))


@router.put("/profile", response_model=APIResponse[dict])
def save_profile(request: ProfileUpdate, authorization: Optional[str] = Header(None),
                 service: AuthService = Depends(get_auth_service)):
    try:
        return APIResponse(success=True, data=service.profile(_profile_token(authorization), request), message="Profile updated.")
    except PermissionError as exc:
        raise HTTPException(status_code=401, detail=str(exc))
    except ValueError as exc:
        raise HTTPException(status_code=409, detail=str(exc))
