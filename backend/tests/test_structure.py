import pytest
from app.agents.triage_agent import MedicalTriageAgent
from app.tools.triage_tool import evaluate_triage_rules
from app.tools.patient_history_tool import get_patient_history
from app.tools.hospital_data_tool import query_hospital_facilities
from app.tools.hospital_routing_tool import route_to_recommended_hospital
from app.tools.embedding_tool import search_medical_embeddings
from app.services.triage_service import TriageService
from app.services.routing_service import RoutingService
from app.repositories.patient_repository import PatientRepository
from app.repositories.hospital_repository import HospitalRepository
from app.schemas.triage import TriageRequest, TriageLevel


def test_agent_and_tools_initialization():
    """Verify that the medical triage agent registers all 5 specified tools."""
    agent = MedicalTriageAgent()
    assert len(agent.tools) == 5
    tool_names = [t.name for t in agent.tools]
    assert "evaluate_triage_rules" in tool_names
    assert "get_patient_history" in tool_names
    assert "query_hospital_facilities" in tool_names
    assert "route_to_recommended_hospital" in tool_names
    assert "search_medical_embeddings" in tool_names


def test_triage_service_placeholder():
    """Verify that triage service handles a request payload gracefully."""
    service = TriageService()
    req = TriageRequest(
        chief_complaint="Severe abdominal pain",
        symptoms=["nausea", "fever"]
    )
    res = service.evaluate_triage(req)
    assert res.assessment is not None
    assert res.assessment.triage_level in list(TriageLevel)
    assert "Severe abdominal pain" in res.assessment.primary_concerns


def test_repositories_instantiation():
    """Verify repository classes can be initialized."""
    patient_repo = PatientRepository()
    hospital_repo = HospitalRepository()
    assert patient_repo.get_by_id("any") is None
    assert hospital_repo.get_by_id("any") is None


def test_groq_llm_and_gemini_embeddings():
    """Verify that get_llm instantiates ChatGroq and get_embeddings instantiates Gemini."""
    from langchain_groq import ChatGroq
    from langchain_google_genai import GoogleGenerativeAIEmbeddings
    from app.core.llm import get_llm, get_embeddings, reset_llm_cache
    from app.core.config import get_settings

    reset_llm_cache()
    settings = get_settings()
    assert settings.GROQ_MODEL_NAME is not None

    llm = get_llm()
    assert isinstance(llm, ChatGroq)
    assert llm.model_name == settings.GROQ_MODEL_NAME or llm.model == settings.GROQ_MODEL_NAME

    embeddings = get_embeddings()
    assert isinstance(embeddings, GoogleGenerativeAIEmbeddings)
    assert embeddings.model == settings.GEMINI_EMBEDDING_MODEL


def test_agent_runnable_binding_with_groq():
    """Verify MedicalTriageAgent binds its clinical tools to the Groq LLM."""
    agent = MedicalTriageAgent()
    runnable = agent._get_runnable()
    assert runnable is not None
