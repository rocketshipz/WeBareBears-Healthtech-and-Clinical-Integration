import logging
from typing import Any, Dict, Optional
from app.repositories.patient_repository import PatientRepository
from app.schemas.patient import PatientProfile

logger = logging.getLogger(__name__)


class PatientService:
    """Service layer for patient profile and history business logic."""

    def __init__(self, repository: Optional[PatientRepository] = None):
        self.repository = repository or PatientRepository()

    def get_patient_profile(self, patient_id: str) -> Optional[PatientProfile]:
        """Return the formatted patient profile, or None if there is no record."""
        entity = self.repository.get_by_id(patient_id)
        if not entity:
            return None
        contact = " ".join(
            p for p in (
                entity.emergency_contact_name,
                f"({entity.emergency_contact_relation})" if entity.emergency_contact_relation else None,
                entity.emergency_contact_phone,
            ) if p
        ) or None
        return PatientProfile(
            patient_id=entity.user_id,
            date_of_birth=entity.date_of_birth,
            age=entity.age,
            gender=entity.sex_at_birth,
            blood_type=entity.blood_type,
            height_cm=float(entity.height_cm) if entity.height_cm is not None else None,
            weight_kg=float(entity.weight_kg) if entity.weight_kg is not None else None,
            medical_conditions=entity.chronic_conditions or [],
            allergies=entity.allergies or [],
            current_medications=entity.current_medications or [],
            past_surgeries=entity.past_surgeries or [],
            family_history=entity.family_history or [],
            smoking_status=entity.smoking_status,
            alcohol_use=entity.alcohol_use,
            emergency_contact=contact,
        )

    def get_agent_context(self, patient_id: str) -> Dict[str, Any]:
        """Compact context for the triage agent. Empty unless the user consented."""
        entity = self.repository.get_by_id(patient_id)
        if not entity or not entity.history_consent:
            return {}
        ctx: Dict[str, Any] = {
            "age": entity.age,
            "sex_at_birth": entity.sex_at_birth,
            "chronic_conditions": [c.get("name") for c in (entity.chronic_conditions or [])],
            "allergies": [a.get("substance") for a in (entity.allergies or [])],
            "current_medications": [m.get("name") for m in (entity.current_medications or [])],
        }
        return {k: v for k, v in ctx.items() if v not in (None, [], "unspecified")}
