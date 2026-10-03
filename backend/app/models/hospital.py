from typing import Optional, List
from dataclasses import dataclass, field
from datetime import datetime, timezone


@dataclass
class Hospital:
    """Domain entity placeholder for hospital/facility record."""
    hospital_id: str
    name: str
    address: str
    latitude: float
    longitude: float
    has_emergency_room: bool = True
    specialties: List[str] = field(default_factory=list)
    available_beds: Optional[int] = None
    icu_status: Optional[str] = None
    contact_phone: Optional[str] = None
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
