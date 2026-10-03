from enum import Enum
from typing import Dict, List, Optional, Any
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
    session_id: Optional[str] = Field(None, description="Conversation session ID")
    patient_id: Optional[str] = Field(None, description="Patient ID if available")


class TriageChatResponse(BaseModel):
    """Response from conversational triage interaction."""
    reply: str
    session_id: Optional[str] = None
    assessment: Optional[TriageAssessment] = None
    recommended_hospitals: List[HospitalRecommendation] = Field(default_factory=list)
