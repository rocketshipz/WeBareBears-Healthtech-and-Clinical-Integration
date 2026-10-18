"""Stores each classified screening in patient_triage_reports, keyed by its session id.

The report is built only from the rules engine result (CLAUDE.md §4): the client never sends a level.
"""
import logging
from datetime import datetime, timezone
from typing import Optional

from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.models.user import User
from app.repositories.triage_report_repository import TriageReportRepository

logger = logging.getLogger(__name__)


def normalize_ic(ic: str) -> Optional[str]:
    """The 12 digits of a Malaysian IC number, or None if it is not one."""
    normalized = (ic or "").replace("-", "").replace(" ", "")
    if len(normalized) != 12 or not normalized.isascii() or not normalized.isdigit():
        return None
    return normalized


def find_user_by_ic(db: Session, normalized_ic: str) -> Optional[User]:
    return db.query(User).filter(
        func.replace(func.replace(User.ic, "-", ""), " ", "") == normalized_ic).first()


def build_report(session) -> dict:
    """The stored report, from the engine result. Keeps the keys the admin app's TriageSummary reads."""
    result = session.triage_result
    chief_complaint = getattr(session, "chief_complaint", None)
    main_symptom = getattr(session, "main_symptom", None)
    return {
        "symptom": main_symptom or chief_complaint,
        "severity": f"Level {result['triage_level']} - {result['triage_name']}",
        "duration": None,
        "danger_signs": result.get("key_findings", []),
        "level": result["triage_level"],
        "submitted_at": datetime.now(timezone.utc).isoformat(),
        "triage_name": result["triage_name"],
        "level_advice": result.get("level_advice"),
        "emergency_advice": result.get("emergency_advice", []),
        "call_999": bool(result.get("call_999")),
        "chief_complaint": chief_complaint,
        "main_symptom": main_symptom,
        "source_references": [{"rule_id": ref["rule_id"], "criterion": ref.get("criterion", "")}
                              for ref in result.get("source_references", [])],
        "mode": get_settings().TRIAGE_MODE.strip().lower(),
    }


def save_report(session, db: Optional[Session]) -> Optional[str]:
    """Upsert the report once the screening is classified. Returns the report id (= session id), or None.

    Anonymous screenings are not stored. A database error is logged and never breaks the chat reply.
    """
    result = session.triage_result or {}
    if result.get("status") != "classified" or not session.owner_id or db is None:
        return None
    try:
        saved = TriageReportRepository(db).upsert_classified(
            session.session_id, session.owner_id, getattr(session, "subject", None), build_report(session))
    except Exception as e:
        db.rollback()
        logger.error(f"Could not save triage report {session.session_id}: {e}")
        return None
    return session.session_id if saved else None


def link_subject(db: Session, session_id: str, user_id: str, ic: str) -> str:
    """Link a report to the account of the person it is about. Returns "linked", or why it could not be:
    "not_found" (no such report of this user), "invalid_ic" or "no_account"."""
    repo = TriageReportRepository(db)
    row = repo.get_owned(session_id, user_id)
    if row is None:
        return "not_found"
    normalized = normalize_ic(ic)
    if normalized is None:
        return "invalid_ic"
    person = find_user_by_ic(db, normalized)
    if person is None:
        return "no_account"
    if person.id == user_id:
        repo.set_subject(row, "self", None)
    else:
        repo.set_subject(row, "other", person.id)
    return "linked"
