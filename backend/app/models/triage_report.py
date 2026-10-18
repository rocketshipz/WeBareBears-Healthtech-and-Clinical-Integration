from datetime import datetime, timezone
from sqlalchemy import JSON, Column, DateTime, ForeignKey, String, Text
from app.core.database import Base


def _utcnow():
    return datetime.now(timezone.utc)


class SavedReport(Base):
    """A classified triage screening, keyed by its chat session id.

    `report` is built from the rules engine result only (never from LLM text or the client).
    `user_id` is who ran the screening. When it was for someone else (`subject="other"`),
    `subject_user_id` is that person's account, linked by IC, so staff find it at check-in.
    """
    __tablename__ = "patient_triage_reports"

    session_id = Column(String(64), primary_key=True)
    user_id = Column(String(50), ForeignKey("users.id"), nullable=False, index=True)
    subject = Column(String(10), nullable=True)  # self|other|unknown (NULL on older rows = self)
    subject_user_id = Column(String(50), ForeignKey("users.id"), nullable=True, index=True)
    # Flat copies of the main report fields, for reading the table directly (the Supabase table requires them).
    main_symptom = Column(Text, nullable=False)
    reported_severity = Column(Text, nullable=False)
    danger_signs = Column(Text, nullable=False)
    duration = Column(Text, nullable=True)
    report_id = Column(String(64), nullable=True)
    report = Column(JSON, nullable=False)
    created_at = Column(DateTime(timezone=True), default=_utcnow, nullable=False)
    updated_at = Column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow, nullable=True)
