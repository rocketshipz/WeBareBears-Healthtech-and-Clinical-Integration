import logging
from fastapi import APIRouter, Depends, status
from app.schemas.common import APIResponse
from app.schemas.triage import (
    TriageRequest,
    TriageResponse,
    TriageChatRequest,
    TriageChatResponse,
)
from app.services.triage_service import TriageService
from app.agents.triage_agent import MedicalTriageAgent

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/triage", tags=["Triage"])

# Shared service instances
_triage_service = TriageService()
_triage_agent = MedicalTriageAgent()


def get_triage_service() -> TriageService:
    return _triage_service


def get_triage_agent() -> MedicalTriageAgent:
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
    agent: MedicalTriageAgent = Depends(get_triage_agent)
):
    """Conversational interaction with the Medical Triage AI Agent."""
    logger.info(f"Incoming triage chat request: {request.message[:40]}")
    context = {"patient_id": request.patient_id} if request.patient_id else None
    agent_reply = agent.run(request.message, context=context)
    
    return APIResponse(
        success=True,
        data=TriageChatResponse(
            reply=agent_reply,
            session_id=request.session_id
        ),
        message="Agent response generated."
    )
