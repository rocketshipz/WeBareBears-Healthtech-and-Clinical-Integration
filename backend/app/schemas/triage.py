from enum import Enum
from typing import Dict, List, Optional, Any, Union
from pydantic import BaseModel, Field
from app.schemas.hospital import Coordinates, HospitalRecommendation


class TriageLevel(str, Enum):
    """Standard emergency triage classification levels (e.g. ESI / CTAS inspired)."""
    RESUSCITATION = "LEVEL_1_RESUSCITATION"
    EMERGENT = "LEVEL_2_EMERGENT"
    URGENT = "LEVEL_3_URGENT"
    LESS_URGENT = "LEVEL_4_LESS_URGENT"
    NON_URGENT = "LEVEL_5_NON_URGENT"


class VitalSigns(BaseModel):
    """Optional physiological vital signs reported by user or device."""
    heart_rate_bpm: Optional[int] = Field(None, description="Heart rate in beats per minute")
    blood_pressure_systolic: Optional[int] = Field(None, description="Systolic blood pressure (mmHg)")
    blood_pressure_diastolic: Optional[int] = Field(None, description="Diastolic blood pressure (mmHg)")
    oxygen_saturation_percent: Optional[float] = Field(None, description="SpO2 percentage")
    respiratory_rate: Optional[int] = Field(None, description="Breaths per minute")
    temperature_celsius: Optional[float] = Field(None, description="Body temperature in Celsius")


class TriageAssessment(BaseModel):
    """Deterministic or agentic triage assessment output."""
    triage_level: TriageLevel
    urgency_description: str
    primary_concerns: List[str] = Field(default_factory=list)
    immediate_actions: List[str] = Field(default_factory=list)
    required_specialties: List[str] = Field(default_factory=list)
    clinical_rationale: str


class TriageRequest(BaseModel):
    """Input payload for a triage assessment request from Flutter mobile client."""
    patient_id: Optional[str] = Field(None, description="Patient ID if logged in")
    chief_complaint: str = Field(..., description="Main symptom or problem reported by patient")
    symptoms: List[str] = Field(default_factory=list, description="List of concurrent symptoms")
    vital_signs: Optional[VitalSigns] = None
    patient_location: Optional[Coordinates] = None
    notes: Optional[str] = None


class TriageResponse(BaseModel):
    """Full triage evaluation result returned to Flutter mobile client."""
    assessment: TriageAssessment
    recommended_hospitals: List[HospitalRecommendation] = Field(default_factory=list)
    disclaimer: str = (
        "This tool provides first-level emergency triage guidance and does not "
        "replace professional medical judgment. In case of life-threatening emergency, "
        "call emergency services immediately."
    )


class TriageChatRequest(BaseModel):
    """Payload for conversational interaction with the Medical Triage Agent."""
    message: str = Field(..., description="User query or message")
    session_id: Optional[str] = Field(None, max_length=64, description="Conversation session ID")
    patient_id: Optional[str] = Field(
        None, description="Ignored: the profile comes from the login token (Authorization: Bearer ...)")
    selected_options: Optional[List[str]] = Field(
        None, description="Option(s) picked from the previous selection, exactly as offered (several if multi_select)")
    note: Optional[str] = Field(
        None, description="Optional extra details typed alongside a picked option (read as new information)")


class TriageChatResponse(BaseModel):
    """Response from conversational triage interaction."""
    type: str = Field("text", description="'text' (free-text reply) or 'selection' (pick from the options)")
    response: Union[str, List[str]] = Field("", description="Text message, or the list of options for a selection")
    question: Optional[str] = Field(None, description="Question to show above the options when type is 'selection'")
    multi_select: bool = Field(False, description="Selection allows ticking several options")
    exclusive_options: List[str] = Field(
        default_factory=list, description="Options that cannot be ticked together with any other (e.g. 'None of these')")
    suggested_options: List[str] = Field(
        default_factory=list,
        description="Options matching what the user already mentioned: shown pre-selected, the user still confirms")
    chief_complaint: Optional[str] = Field(
        None, description="The user's own words for their main problem (the message where a complaint was first "
                          "identified); null until then")
    main_symptom: Optional[str] = Field(
        None, description="Short plain summary of the main symptom for the report, set once the screening is "
                          "classified (falls back to chief_complaint)")
    reply: str = Field(..., description="Plain text of the turn (the question for a selection); kept for compatibility")
    session_id: Optional[str] = None
    report_id: Optional[str] = Field(
        None, description="Id of the stored triage report (= session_id), set once a logged-in screening is classified")
    subject: Optional[str] = Field(
        None, description="Who the screening is for: 'self', 'other', or null if not known (agent mode)")
    assessment: Optional[TriageAssessment] = None
    recommended_hospitals: List[HospitalRecommendation] = Field(default_factory=list)


class ReportSubjectRequest(BaseModel):
    """Link a triage report to the account of the person it is about, by their IC number."""
    ic: str = Field(..., max_length=20, description="The person's IC number (with or without dashes)")
