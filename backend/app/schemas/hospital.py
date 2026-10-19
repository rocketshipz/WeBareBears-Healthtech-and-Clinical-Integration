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
    activity_level: Optional[str] = Field(None, description="ED activity: low, moderate, busy, very busy")
    available_ed_spaces: Optional[int] = None
    google_place_id: Optional[str] = None
    location_source: str = Field("database", description="database, or google when the DB coordinate was wrong")


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
    travel_time_source: str = Field("estimate", description="traffic (Google live traffic) or estimate")
    road_distance_km: Optional[float] = None
    suitability_score: float = Field(..., ge=0.0, le=1.0, description="Confidence/suitability score")
    recommendation_reason: str
    badges: List[str] = Field(default_factory=list, description="e.g. Best match, Closest, Least busy")


class HospitalRoutingResponse(BaseModel):
    """Ranked hospitals, with the triage level (if any, from the last 24 h) that shaped the ranking."""
    triage_level_used: Optional[int] = None
    triage_age_hours: Optional[float] = None
    recommendations: List[HospitalRecommendation] = Field(default_factory=list)
