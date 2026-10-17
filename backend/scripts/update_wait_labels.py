"""Run the waiting-time label update once: `python scripts/update_wait_labels.py` from backend/."""
import logging
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.services.wait_time_service import update_wait_labels  # noqa: E402

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    print(f"Rows updated: {update_wait_labels()}")
