import logging
from datetime import datetime
from typing import Optional
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from app.models.triage_report import SavedReport

logger = logging.getLogger(__name__)


def ensure_table(session: Session) -> None:
    """Create the table on a fresh database."""
    SavedReport.__table__.create(session.get_bind(), checkfirst=True)


class TriageReportRepository:
    """Data access for patient_triage_reports."""

    def __init__(self, session: Session):
        self.session = session
        ensure_table(session)

    def upsert_classified(self, session_id: str, user_id: str, subject: Optional[str], report: dict) -> bool:
        """Insert or update the report of a session. False if the row belongs to another user (left untouched)."""
        row = self.session.get(SavedReport, session_id)
        if row is None:
            row = SavedReport(session_id=session_id, user_id=user_id, subject=subject or "unknown")
            self.session.add(row)
        elif row.user_id != user_id:
            # A stale client session id after a restart must never overwrite someone else's report.
            logger.warning(f"Triage report {session_id} belongs to another user; not overwritten.")
            return False
        elif subject in ("self", "other"):  # a linked subject is kept unless the screening now knows better
            row.subject = subject
        row.report = report
        row.main_symptom = report.get("symptom") or "Not specified"
        row.reported_severity = report.get("severity") or "Not specified"
        row.danger_signs = ", ".join(report.get("danger_signs") or []) or "None reported"
        row.duration = report.get("duration")
        self.session.commit()
        return True

    def get_owned(self, session_id: str, user_id: str) -> Optional[SavedReport]:
        row = self.session.get(SavedReport, session_id)
        return row if row is not None and row.user_id == user_id else None

    def set_subject(self, row: SavedReport, subject: str, subject_user_id: Optional[str]) -> None:
        row.subject, row.subject_user_id = subject, subject_user_id
        self.session.commit()

    def latest_recent(self, user_id: str, since: datetime) -> Optional[SavedReport]:
        """The newest report this user ran (for anyone) or that is linked to them, saved at or after `since`."""
        saved_at = func.coalesce(SavedReport.updated_at, SavedReport.created_at)
        return self.session.query(SavedReport).filter(
            or_(SavedReport.user_id == user_id, SavedReport.subject_user_id == user_id),
            saved_at >= since,
        ).order_by(saved_at.desc(), SavedReport.session_id.desc()).first()

    def latest_for_patient(self, user_id: str) -> Optional[SavedReport]:
        """The newest report about this person: linked to them, or run by them and not for someone else."""
        return self.session.query(SavedReport).filter(or_(
            SavedReport.subject_user_id == user_id,
            and_(SavedReport.user_id == user_id,
                 or_(SavedReport.subject.is_(None), SavedReport.subject != "other")),
        )).order_by(func.coalesce(SavedReport.updated_at, SavedReport.created_at).desc(),
                    SavedReport.session_id.desc()).first()
