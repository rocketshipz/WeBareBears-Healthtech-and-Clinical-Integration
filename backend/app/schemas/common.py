from typing import Generic, Optional, TypeVar
from pydantic import BaseModel

T = TypeVar("T")


class APIResponse(BaseModel, Generic[T]):
    """Standardized API response wrapper."""
    success: bool
    data: Optional[T] = None
    message: Optional[str] = None
    error: Optional[str] = None


class HealthStatus(BaseModel):
    """Health check response schema."""
    status: str
    version: str
    environment: str
    timestamp: str
