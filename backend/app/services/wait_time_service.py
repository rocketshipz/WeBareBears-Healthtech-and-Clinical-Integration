import logging
import re
from typing import Optional

from sqlalchemy import text

from app.core.config import get_settings
from app.core.database import get_session_factory

logger = logging.getLogger(__name__)

_IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def label_for_ratio(ratio: float, low_max: float, moderate_max: float, busy_max: float) -> str:
    """Maps a load ratio to a waiting-time label."""
    if ratio < low_max:
        return "low"
    if ratio < moderate_max:
        return "moderate"
    if ratio < busy_max:
        return "busy"
    return "very busy"


def _ident(name: str) -> str:
    """Validates a configured SQL identifier (config only, never user input) and quotes it."""
    if not _IDENT_RE.match(name):
        raise ValueError(f"Invalid SQL identifier in settings: {name!r}")
    return f'"{name}"'


def update_wait_labels() -> Optional[int]:
    """Recomputes the waiting-time label for every row and writes it back.

    Rows with a NULL or non-positive denominator are skipped. Returns the number of
    rows updated, or None if the database is unavailable or the run failed.
    """
    s = get_settings()
    factory = get_session_factory()
    if factory is None:
        logger.warning("[wait_time] No database session factory; skipping run.")
        return None

    table, key = _ident(s.WAIT_LABEL_TABLE), _ident(s.WAIT_LABEL_KEY_COL)
    num, den = _ident(s.WAIT_LABEL_NUMERATOR_COL), _ident(s.WAIT_LABEL_DENOMINATOR_COL)
    label_col = _ident(s.WAIT_LABEL_COL)

    session = factory()
    try:
        rows = session.execute(text(f"SELECT {key}, {num}, {den} FROM {table}")).all()
        updates = []
        for row_key, numerator, denominator in rows:
            if numerator is None or denominator is None or float(denominator) <= 0:
                continue
            ratio = float(numerator) / float(denominator)
            updates.append({
                "k": row_key,
                "label": label_for_ratio(
                    ratio, s.WAIT_LABEL_LOW_MAX, s.WAIT_LABEL_MODERATE_MAX, s.WAIT_LABEL_BUSY_MAX
                ),
            })
        if updates:
            session.execute(
                text(f"UPDATE {table} SET {label_col} = :label WHERE {key} = :k"), updates
            )
        session.commit()
        logger.info(f"[wait_time] Updated {len(updates)} of {len(rows)} rows.")
        return len(updates)
    except Exception as e:
        session.rollback()
        logger.exception(f"[wait_time] Update failed: {e}")
        return None
    finally:
        session.close()
