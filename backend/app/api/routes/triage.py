import logging
from typing import Optional, Union
from fastapi import APIRouter, Depends, HTTPException, status
from app.schemas.common import APIResponse
from app.schemas.triage import (
    TriageRequest,
    TriageResponse,
    TriageChatRequest,
    TriageChatResponse,
    TriageAssessment,
    TriageLevel,
    ReportSubjectRequest,
)
from app.api.routes.auth import get_optional_user
from app.core.config import get_settings
from app.core.database import get_db_session
from app.services.patient_context import load_profile
from app.services.symptom_summary import ensure_main_symptom
from app.services.triage_report_service import link_subject, save_report
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
    db=Depends(get_db_session),
):
    """Conversational interaction with the Medical Triage AI Agent."""
    logger.info(f"Incoming triage chat request: {request.message[:40]}")
    # The profile only ever comes from the login token, never from the request body.
    user_id = (user or {}).get("id")
    context = None
    if agent.has_session(request.session_id):
        # A screening can only be continued by the user who started it (it holds their health profile).
        owner = agent.session_owner(request.session_id)
        if owner is not None and owner != user_id:
            logger.warning(f"Triage session {request.session_id} belongs to another user; request refused.")
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN,
                                detail="This screening belongs to another user. Please start a new one.")
    elif user_id:
        # New screening: query the user's health profile (user_information) once, before triage starts.
        context = {"patient_id": user_id, "profile": load_profile(user_id)}
        logger.info(f"Triage session started for user {user_id} "
                    f"(profile fields: {sorted(context['profile']) or 'none'})")
    session = agent.run_session(request.message, context=context, session_id=request.session_id,
                                selected_options=request.selected_options, note=request.note)
    ensure_main_symptom(session)  # once classified: a short summary for the report
    report_id = save_report(session, db)  # once classified and logged in: stored, keyed by session id

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
            report_id=report_id,
            subject=getattr(session, "subject", None),
            assessment=_assessment_from_result(session.triage_result),
            chief_complaint=getattr(session, "chief_complaint", None),
            main_symptom=getattr(session, "main_symptom", None),
            progress=getattr(session, "progress", None),
        ),
        message="Agent response generated."
    )


_LINK_ERRORS = {
    "not_found": (status.HTTP_404_NOT_FOUND, "Triage report not found."),
    "invalid_ic": (422, "Enter a valid 12-digit IC number."),
    "no_account": (status.HTTP_404_NOT_FOUND, "No TriageMY account found for this IC number."),
}


@router.put("/reports/{session_id}/subject", status_code=status.HTTP_200_OK)
def set_report_subject(
    session_id: str,
    request: ReportSubjectRequest,
    user: Optional[dict] = Depends(get_optional_user),
    db=Depends(get_db_session),
):
    """Link the user's own report to the account of the person it was for (by IC), for hospital check-in."""
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Please log in to update your report.")
    if db is None:
        raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail="Database unavailable.")
    outcome = link_subject(db, session_id, user["id"], request.ic)
    if outcome in _LINK_ERRORS:
        code, detail = _LINK_ERRORS[outcome]
        raise HTTPException(status_code=code, detail=detail)
    # Only confirm the link: never reveal who owns the IC.
    return {"linked": True}


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
