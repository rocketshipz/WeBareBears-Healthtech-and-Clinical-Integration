import logging
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.routes.auth import get_current_user, get_optional_user
from app.core.database import get_db_session
from app.core.location_detector import is_valid_coordinates
from app.schemas.common import APIResponse
from app.schemas.hospital import Coordinates, HospitalRoutingResponse
from app.services.routing_service import RoutingService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/hospitals", tags=["Hospitals"])

_routing_service = RoutingService()


def get_routing_service() -> RoutingService:
    return _routing_service


@router.get("/recommendations", response_model=APIResponse[HospitalRoutingResponse],
            status_code=status.HTTP_200_OK)
async def get_recommendations(
    lat: float = Query(..., description="Patient latitude"),
    lon: float = Query(..., description="Patient longitude"),
    session_id: Optional[str] = Query(None, description="Triage report the user came from"),
    radius_km: float = Query(30.0, gt=0, le=200),
    limit: int = Query(5, ge=1, le=20),
    clinics: int = Query(0, ge=0, le=20, description="With no recent triage, also rank this many walk-in clinics"),
    user: Optional[dict] = Depends(get_optional_user),
    db: Optional[Session] = Depends(get_db_session),
    service: RoutingService = Depends(get_routing_service),
):
    """Nearby hospitals ranked by travel time and ED busyness, weighted by the user's triage level (last 24 h).

    Level 4-5: walk-in clinics first, then one ED. No recent triage and clinics > 0: clinics as a separate list.
    """
    if not is_valid_coordinates(lat, lon):
        raise HTTPException(status_code=422,detail="Invalid coordinates.")
    if db is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Hospital data unavailable.")
    try:
        result = service.recommend_for_user(
            db, Coordinates(latitude=lat, longitude=lon),
            user_id=user["id"] if user else None, session_id=session_id,
            max_radius_km=radius_km, limit=limit, clinics=clinics,
        )
    except Exception as e:
        logger.exception(f"[hospitals] Ranking failed: {e}")
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Hospital data unavailable.")
    return APIResponse(success=True, data=result, message="Hospital recommendations retrieved.")


@router.delete("/triage-context", response_model=APIResponse[dict], status_code=status.HTTP_200_OK)
async def clear_triage_context(
    user: dict = Depends(get_current_user),
    db: Optional[Session] = Depends(get_db_session),
    service: RoutingService = Depends(get_routing_service),
):
    """Stop using the user's recent triage result for hospital routing. The triage reports are kept."""
    if db is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database unavailable.")
    service.clear_recent_triage(db, user["id"])
    return APIResponse(success=True, data={"cleared": True}, message="Triage result cleared from routing.")
