from typing import Optional, List, Dict, Any
from dataclasses import dataclass, field
from datetime import datetime, timezone


@dataclass
class TriageRecord:
    """Domain entity placeholder for triage assessment record."""
    record_id: str
    patient_id: Optional[str] = None
    chief_complaint: str = ""
    symptoms: List[str] = field(default_factory=list)
    vital_signs: Dict[str, Any] = field(default_factory=dict)
    triage_level: str = "LEVEL_3_URGENT"
    recommended_hospital_ids: List[str] = field(default_factory=list)
    created_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
