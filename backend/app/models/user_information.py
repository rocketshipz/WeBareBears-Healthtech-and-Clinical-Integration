from datetime import date, datetime, timezone
from sqlalchemy import (
    JSON,
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Numeric,
    String,
    Text,
    func,
)
from app.core.database import Base


def _utcnow():
    return datetime.now(timezone.utc)


class UserInformation(Base):
    """Demographics and medical background for a user (1:1 with users).

    Context for the triage agent only. It never stores a triage level.
    Pregnancy, anticoagulants etc. are asked live during triage, not stored.
    """
    __tablename__ = "user_information"

    user_id = Column(String(50), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True)
    date_of_birth = Column(Date, nullable=False)
    sex_at_birth = Column(String(20), default="unspecified", nullable=False)  # male|female|intersex|unspecified
    nationality = Column(Text, nullable=True)
    preferred_language = Column(Text, nullable=True)
    height_cm = Column(Numeric(5, 1), nullable=True)
    weight_kg = Column(Numeric(5, 1), nullable=True)
    blood_type = Column(String(10), default="unknown", nullable=False)  # A+ ... O-, unknown

    chronic_conditions = Column(JSON, default=list, nullable=False)   # [{name, since_year, notes}]
    allergies = Column(JSON, default=list, nullable=False)            # [{substance, reaction, severity}]
    current_medications = Column(JSON, default=list, nullable=False)  # [{name, dose, frequency}]
    past_surgeries = Column(JSON, default=list, nullable=False)
    family_history = Column(JSON, default=list, nullable=False)
    smoking_status = Column(String(20), nullable=True)  # never|former|current
    alcohol_use = Column(String(20), nullable=True)     # none|occasional|regular

    emergency_contact_name = Column(Text, nullable=True)
    emergency_contact_phone = Column(Text, nullable=True)
    emergency_contact_relation = Column(Text, nullable=True)
    organ_donor = Column(Boolean, nullable=True)
    location_consent = Column(Boolean, default=False, nullable=False)

    medical_info_updated_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), default=_utcnow, server_default=func.now(), nullable=False)
    updated_at = Column(
        DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, server_default=func.now(), nullable=False
    )

    @property
    def age(self) -> int:
        """Age in whole years, derived from date_of_birth."""
        today = date.today()
        dob = self.date_of_birth
        return today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
