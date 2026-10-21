"""Pre-fetch clinic opening hours from Google Places: `python scripts/check_clinic_hours.py --state PERAK` from backend/.

Routing looks hours up lazily for shortlisted clinics; this fills clinic_place_check ahead of a demo so the
first request in an area has no lookup delay. Each clinic is one Places Text Search call (Enterprise SKU).
Options: --state, --near LAT LON with --radius KM (nearest first), --only-new (only clinics never checked,
checked under older rules, or over 30 days ago), --limit N.
"""
import argparse
import logging
import sys
import time
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import httpx  # noqa: E402

from app.core.config import get_settings  # noqa: E402
from app.core.database import get_session_factory  # noqa: E402
from app.core.location_detector import calculate_haversine_distance  # noqa: E402
from app.models.clinic_directory import ClinicDirectory  # noqa: E402
from app.repositories.clinic_repository import ClinicRepository  # noqa: E402
from app.services.clinic_hours_service import lookup_and_store, needs_lookup, stored_hours  # noqa: E402

REQUEST_INTERVAL_SECONDS = 0.2

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    parser = argparse.ArgumentParser()
    parser.add_argument("--state", default=None, help="clinic_data state, e.g. PERAK (default: all)")
    parser.add_argument("--near", type=float, nargs=2, metavar=("LAT", "LON"), default=None,
                        help="only clinics within --radius km of this point, nearest first")
    parser.add_argument("--radius", type=float, default=5.0, help="km around --near (default 5)")
    parser.add_argument("--only-new", action="store_true", help="skip clinics with a current check")
    parser.add_argument("--limit", type=int, default=None, help="check at most N clinics (trial run)")
    args = parser.parse_args()

    key = get_settings().GOOGLE_MAPS_API_KEY
    if not key:
        sys.exit("GOOGLE_MAPS_API_KEY is not set in backend/.env")
    with get_session_factory()() as session:
        rows = ClinicRepository(session).list_routable()
        if args.state:
            codes = {c for (c,) in session.query(ClinicDirectory.clinic_code)
                     .filter(ClinicDirectory.state.ilike(args.state))}
            rows = [r for r in rows if r.clinic_code in codes]
    if args.near:
        lat, lon = args.near
        km = {r.clinic_code: calculate_haversine_distance(lat, lon, r.db_latitude, r.db_longitude) for r in rows}
        rows = sorted((r for r in rows if km[r.clinic_code] <= args.radius), key=lambda r: km[r.clinic_code])
    if args.only_new:
        now = datetime.now(timezone.utc)
        rows = [r for r in rows if needs_lookup(r, now)]
    rows = rows[:args.limit] if args.limit else rows
    print(f"Checking {len(rows)} clinics.")

    checks = []
    for i, row in enumerate(rows, 1):
        try:
            checks.append(lookup_and_store(row, key))
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429:
                print(f"Places quota reached after {len(checks)}; re-run later with --only-new.")
                break
            sys.exit(f"Places API error: {e.response.text[:300]}")
        except Exception as e:
            logging.warning(f"{row.clinic_code}: lookup failed ({e}); skipped.")
            continue
        if i % 25 == 0:
            print(f"{i}/{len(rows)} checked.")
        time.sleep(REQUEST_INTERVAL_SECONDS)

    print(f"\nChecked {len(checks)}: {dict(Counter(c.status for c in checks))}")
    print(f"Hours now: {dict(Counter(stored_hours([r for r in rows if r.checked_at]).values()))}")
