from typing import List, Optional
from pydantic import BaseModel, Field


class Coordinates(BaseModel):
    """Geographic coordinate representation."""
    latitude: float
    longitude: float


class HospitalInfo(BaseModel):
    """Schema representing hospital or emergency facility metadata."""
    hospital_id: str = Field(..., description="Unique hospital identifier")
    name: str = Field(..., description="Hospital facility name")
    address: str = Field(..., description="Physical address")
    location: Optional[Coordinates] = None
    phone_number: Optional[str] = None
    has_emergency_room: bool = True
    specialties: List[str] = Field(default_factory=list, description="Medical specialties available")
    available_beds: Optional[int] = None
    icu_capacity_status: Optional[str] = Field(None, description="ICU status: AVAILABLE, LIMITED, FULL")
    estimated_wait_time_minutes: Optional[int] = None


class HospitalRoutingRequest(BaseModel):
    """Request schema for routing a patient to a recommended hospital."""
    patient_location: Coordinates
    required_specialties: List[str] = Field(default_factory=list)
    triage_level: Optional[str] = None
    max_radius_km: Optional[float] = 30.0


class HospitalRecommendation(BaseModel):
    """Hospital routing recommendation result."""
    hospital: HospitalInfo
    distance_km: float
    estimated_travel_time_minutes: int
    suitability_score: float = Field(..., ge=0.0, le=1.0, description="Confidence/suitability score")
    recommendation_reason: str
