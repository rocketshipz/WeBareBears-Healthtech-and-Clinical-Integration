import logging
from datetime import datetime
from typing import Optional

from apscheduler.schedulers.background import BackgroundScheduler

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_scheduler: Optional[BackgroundScheduler] = None


def start_scheduler() -> None:
    """Starts background jobs (waiting-time labels). Safe to call more than once."""
    global _scheduler
    settings = get_settings()
    if _scheduler is not None or not settings.WAIT_LABEL_ENABLED:
        return
    from app.services.wait_time_service import update_wait_labels

    _scheduler = BackgroundScheduler()
    _scheduler.add_job(
        update_wait_labels,
        "interval",
        minutes=settings.WAIT_LABEL_INTERVAL_MINUTES,
        next_run_time=datetime.now(),  # also run once at startup
        max_instances=1,
        coalesce=True,
        id="wait_time_labels",
    )
    _scheduler.start()
    logger.info(f"Scheduler started: wait labels every {settings.WAIT_LABEL_INTERVAL_MINUTES} min.")


def stop_scheduler() -> None:
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
