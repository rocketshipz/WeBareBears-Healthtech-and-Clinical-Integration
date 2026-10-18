import logging
from contextlib import contextmanager
from typing import Any, Dict, Iterator, Optional
from app.core.database import get_session_factory
from app.repositories.patient_repository import PatientRepository
from app.schemas.patient import PatientProfile

logger = logging.getLogger(__name__)


class PatientService:
    """Service layer for patient profile and history business logic."""

    def __init__(self, repository: Optional[PatientRepository] = None):
        # Without an injected repository, each call opens its own DB session (see _repo).
        self.repository = repository

    @contextmanager
    def _repo(self) -> Iterator[PatientRepository]:
        """The injected repository, or one on a fresh DB session that is closed afterwards."""
        if self.repository is not None:
            yield self.repository
            return
        session_factory = get_session_factory()
        if session_factory is None:
            yield PatientRepository()  # no database configured: every lookup returns None
            return
        session = session_factory()
        try:
            yield PatientRepository(session)
        finally:
            session.close()

    def get_patient_profile(self, patient_id: str) -> Optional[PatientProfile]:
        """Return the formatted patient profile, or None if there is no record."""
        with self._repo() as repo:
            entity = repo.get_by_id(patient_id)
            return self._profile(entity) if entity else None

    @staticmethod
    def _profile(entity) -> PatientProfile:
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
        """Compact profile for triage (age, sex, condition / allergy / medication names). Empty if no record."""
        with self._repo() as repo:
            entity = repo.get_by_id(patient_id)
            if not entity:
                return {}

            def names(items, key):
                return [i.get(key) for i in (items or []) if isinstance(i, dict) and i.get(key)]

            ctx: Dict[str, Any] = {
                "age": entity.age,
                "sex_at_birth": entity.sex_at_birth,
                "chronic_conditions": names(entity.chronic_conditions, "name"),
                "allergies": names(entity.allergies, "substance"),
                "current_medications": names(entity.current_medications, "name"),
            }
        return {k: v for k, v in ctx.items() if v not in (None, [], "unspecified")}
