import base64
import binascii
from typing import Any, Literal
from pydantic import BaseModel, ConfigDict, Field, field_validator


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

    photo_data_url: str | None = Field(None, max_length=1400000)

    @field_validator('photo_data_url')
    @classmethod
    def validate_photo(cls, value):
        if value is None:
            return value
        try:
            header, encoded = value.split(',', 1)
            image = base64.b64decode(encoded, validate=True)
        except (ValueError, binascii.Error):
            raise ValueError('Invalid profile photo')
        signatures = {
            'data:image/jpeg;base64': image.startswith(b'\xff\xd8\xff'),
            'data:image/png;base64': image.startswith(b'\x89PNG\r\n\x1a\n'),
            'data:image/webp;base64': image.startswith(b'RIFF') and image[8:12] == b'WEBP',
        }
        if not signatures.get(header) or len(image) > 1024 * 1024:
            raise ValueError('Choose a JPEG, PNG or WebP photo smaller than 1 MB')
        return value
