import json
import logging
from langchain_core.tools import tool
from app.services.patient_context import load_profile

logger = logging.getLogger(__name__)


@tool
def get_patient_history(patient_id: str) -> str:
    """Retrieve the logged-in user's health profile: age, sex at birth, chronic conditions, allergies, medications.

    The profile describes the logged-in user only. Use it only when the screening is for them.

    Args:
        patient_id: The unique identifier of the patient.

    Returns:
        JSON string of the profile ({"status": "not_found"} if there is none).
    """
    logger.info(f"[PatientHistoryTool] Looking up history for patient: {patient_id}")
    profile = load_profile(patient_id)
    if not profile:
        return json.dumps({"status": "not_found", "patient_id": patient_id})
    return json.dumps({"status": "ok", "patient_id": patient_id, "profile": profile})
