from typing import Any, Literal
from pydantic import BaseModel, ConfigDict, Field


class ProfileUpdate(BaseModel):
    """Editable medical details only; account identity cannot be changed here."""
    model_config = ConfigDict(extra="forbid")
    preferred_language: str | None = None
    height_cm: float | None = Field(None, gt=0, le=9999.9)
    weight_kg: float | None = Field(None, gt=0, le=9999.9)
    blood_type: Literal["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-", "unknown"] = "unknown"
    chronic_conditions: list[dict[str, Any]] = Field(default_factory=list)
    allergies: list[dict[str, Any]] = Field(default_factory=list)
    current_medications: list[dict[str, Any]] = Field(default_factory=list)
    past_surgeries: list[str] = Field(default_factory=list)
    family_history: list[str] = Field(default_factory=list)
    smoking_status: Literal["never", "former", "current"] | None = None
    alcohol_use: Literal["none", "occasional", "regular"] | None = None
    emergency_contact_name: str | None = None
    emergency_contact_phone: str | None = None
    emergency_contact_relation: str | None = None
    organ_donor: bool | None = None
    location_consent: bool = False
