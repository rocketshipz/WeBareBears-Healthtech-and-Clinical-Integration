from datetime import date
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class PatientProfile(BaseModel):
    """Schema representing patient demographics and basic health profile."""
    patient_id: str = Field(..., description="Unique identifier for the patient")
    date_of_birth: Optional[date] = Field(None, description="Date of birth")
    age: Optional[int] = Field(None, description="Patient age in years (derived from date_of_birth)")
    gender: Optional[str] = Field(None, description="Sex at birth (male, female, intersex, unspecified)")
    blood_type: Optional[str] = Field(None, description="Patient blood group (e.g. O+, A-)")
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    medical_conditions: List[Dict[str, Any]] = Field(default_factory=list, description="Pre-existing medical conditions")
    allergies: List[Dict[str, Any]] = Field(default_factory=list, description="Known drug/food allergies")
    current_medications: List[Dict[str, Any]] = Field(default_factory=list, description="Currently prescribed medications")
    past_surgeries: List[Any] = Field(default_factory=list)
    family_history: List[Any] = Field(default_factory=list)
    smoking_status: Optional[str] = None
    alcohol_use: Optional[str] = None
    emergency_contact: Optional[str] = Field(None, description="Emergency contact name, relation and phone")


class PatientHistoryResponse(BaseModel):
    """Schema for returning patient medical history details."""
    patient: PatientProfile
    recent_episodes: List[str] = Field(default_factory=list)
    notes: Optional[str] = None
