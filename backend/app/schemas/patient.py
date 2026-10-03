from typing import List, Optional
from pydantic import BaseModel, Field


class PatientProfile(BaseModel):
    """Schema representing patient demographics and basic health profile."""
    patient_id: str = Field(..., description="Unique identifier for the patient")
    age: Optional[int] = Field(None, description="Patient age in years")
    gender: Optional[str] = Field(None, description="Patient gender (e.g., Male, Female, Other)")
    blood_type: Optional[str] = Field(None, description="Patient blood group (e.g. O+, A-)")
    medical_conditions: List[str] = Field(default_factory=list, description="Pre-existing medical conditions")
    allergies: List[str] = Field(default_factory=list, description="Known drug/food allergies")
    current_medications: List[str] = Field(default_factory=list, description="Currently prescribed medications")
    emergency_contact: Optional[str] = Field(None, description="Emergency contact phone number or name")


class PatientHistoryResponse(BaseModel):
    """Schema for returning patient medical history details."""
    patient: PatientProfile
    recent_episodes: List[str] = Field(default_factory=list)
    notes: Optional[str] = None
