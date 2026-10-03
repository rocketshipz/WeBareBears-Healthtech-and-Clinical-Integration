from datetime import datetime, timezone
from fastapi import APIRouter
from app.schemas.common import HealthStatus
from app.core.config import get_settings

router = APIRouter(prefix="/health", tags=["Health"])


@router.get("", response_model=HealthStatus)
async def check_health():
    """Health check endpoint to verify backend service availability."""
    settings = get_settings()
    return HealthStatus(
        status="healthy",
        version="0.1.0",
        environment=settings.ENVIRONMENT,
        timestamp=datetime.now(timezone.utc).isoformat()
    )
