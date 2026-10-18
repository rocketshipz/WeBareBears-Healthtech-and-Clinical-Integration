import logging
from typing import Any, Dict
from fastapi import APIRouter, Depends, HTTPException, status

from app.api.routes.auth import get_current_user
from app.schemas.common import APIResponse
from app.schemas.patient import PatientProfile
from app.services.patient_service import PatientService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/patients", tags=["Patients"])

_patient_service = PatientService()


def get_patient_service() -> PatientService:
    return _patient_service


@router.get("/me", response_model=APIResponse[PatientProfile], status_code=status.HTTP_200_OK)
async def get_my_profile(
    user: dict = Depends(get_current_user),
    service: PatientService = Depends(get_patient_service),
):
    """The logged-in user's health profile (user_information)."""
    profile = service.get_patient_profile(user["id"])
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No health profile found for this user.")
    return APIResponse(success=True, data=profile, message="Patient profile retrieved.")


@router.get("/me/triage-context", response_model=APIResponse[Dict[str, Any]], status_code=status.HTTP_200_OK)
async def get_my_triage_context(
    user: dict = Depends(get_current_user),
    service: PatientService = Depends(get_patient_service),
):
    """The compact profile the triage uses (age, sex, conditions, allergies, medications). Empty if none."""
    return APIResponse(success=True, data=service.get_agent_context(user["id"]),
                       message="Triage context retrieved.")
