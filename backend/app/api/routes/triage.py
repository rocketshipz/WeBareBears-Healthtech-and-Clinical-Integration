import logging
from typing import Optional, Union
from fastapi import APIRouter, Depends, status
from app.schemas.common import APIResponse
from app.schemas.triage import (
    TriageRequest,
    TriageResponse,
    TriageChatRequest,
    TriageChatResponse,
    TriageAssessment,
    TriageLevel,
)
from app.api.routes.auth import get_optional_user
from app.core.config import get_settings
from app.services.patient_context import load_profile
from app.services.triage_service import TriageService
from app.services.triage_controller import HybridTriageController
from app.agents.triage_agent import MedicalTriageAgent

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/triage", tags=["Triage"])

# Shared service instances
_triage_service = TriageService()
_triage_agent = MedicalTriageAgent()
_hybrid_controller = HybridTriageController()


def get_triage_service() -> TriageService:
    return _triage_service


def get_triage_agent() -> Union[MedicalTriageAgent, HybridTriageController]:
    """The chat engine selected by TRIAGE_MODE: "hybrid" (deterministic flow) or "agent" (LLM tool loop)."""
    if get_settings().TRIAGE_MODE.strip().lower() == "hybrid":
        print("Using hybrid triage controller (deterministic flow).")
        return _hybrid_controller
    return _triage_agent


@router.post("/assess", response_model=APIResponse[TriageResponse], status_code=status.HTTP_200_OK)
async def assess_triage(
    request: TriageRequest,
    service: TriageService = Depends(get_triage_service)
):
    """Perform first-level medical triage evaluation and hospital routing recommendation."""
    logger.info(f"Incoming triage assessment request: {request.chief_complaint}")
    result = service.evaluate_triage(request)
    return APIResponse(
        success=True,
        data=result,
        message="Triage assessment completed."
    )


@router.post("/chat", response_model=APIResponse[TriageChatResponse], status_code=status.HTTP_200_OK)
async def chat_triage(
    request: TriageChatRequest,
    agent: Union[MedicalTriageAgent, HybridTriageController] = Depends(get_triage_agent),
    user: Optional[dict] = Depends(get_optional_user),
):
    """Conversational interaction with the Medical Triage AI Agent."""
    logger.info(f"Incoming triage chat request: {request.message[:40]}")
    # The logged-in user (bearer token) first; a body patient_id only without a login.
    patient_id = (user or {}).get("id") or request.patient_id
    context = None
    if patient_id and not agent.has_session(request.session_id):
        # New screening: query the user's health profile (user_information) once, before triage starts.
        context = {"patient_id": patient_id, "profile": load_profile(patient_id)}
    session = agent.run_session(request.message, context=context, session_id=request.session_id,
                                selected_options=request.selected_options, note=request.note)

    output = session.last_output or {"type": "text", "question": None, "response": session.messages[-1].content}
    return APIResponse(
        success=True,
        data=TriageChatResponse(
            type=output["type"],
            response=output["response"],
            question=output["question"],
            multi_select=output.get("multi_select", False),
            exclusive_options=output.get("exclusive_options", []),
            suggested_options=output.get("suggested_options", []),
            reply=output["question"] or output["response"],
            session_id=session.session_id,
            assessment=_assessment_from_result(session.triage_result),
        ),
        message="Agent response generated."
    )


def _assessment_from_result(result: Optional[dict]) -> Optional[TriageAssessment]:
    """Build the API assessment from the rules engine output (never from LLM text)."""
    if not result or result.get("status") != "classified":
        return None
    sources = "; ".join(
        f"{ref['rule_id']}: {ref.get('criterion', '')}" for ref in result.get("source_references", [])
    )
    return TriageAssessment(
        triage_level=TriageLevel(result["triage_code"]),
        urgency_description=f"Level {result['triage_level']} - {result['triage_name']}",
        primary_concerns=result.get("key_findings", []),
        immediate_actions=[a for a in [result.get("level_advice"), *result.get("emergency_advice", [])] if a],
        required_specialties=[],
        clinical_rationale=f"Malaysian Triage Scale 2019 rules matched: {sources}",
    )
