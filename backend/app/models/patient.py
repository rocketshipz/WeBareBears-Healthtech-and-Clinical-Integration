from typing import Optional, List
from dataclasses import dataclass, field
from datetime import datetime, timezone


@dataclass
class Patient:
    """Domain entity placeholder for patient record."""
    patient_id: str
    age: Optional[int] = None
    gender: Optional[str] = None
    blood_type: Optional[str] = None
    allergies: List[str] = field(default_factory=list)
    chronic_conditions: List[str] = field(default_factory=list)
    medications: List[str] = field(default_factory=list)
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
