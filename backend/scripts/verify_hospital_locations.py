"""Check hospital_data coordinates against Google Places: `python scripts/verify_hospital_locations.py` from backend/.

Writes hospital_location_check (hospital_data is not modified). Options: --only-new, --limit N, --reclassify.
The Places daily quota stops a run early; results so far are kept, so continue later with --only-new.
"""
import argparse
import logging
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.database import get_session_factory  # noqa: E402
from app.models.hospital_directory import HospitalDirectory  # noqa: E402
from app.services.hospital_location_service import reclassify, verify_locations  # noqa: E402

if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    parser = argparse.ArgumentParser()
    parser.add_argument("--only-new", action="store_true", help="skip hospitals already checked")
    parser.add_argument("--limit", type=int, default=None, help="check at most N hospitals (trial run)")
    parser.add_argument("--reclassify", action="store_true",
                        help="re-apply the matching rules to stored results, without calling Google")
    args = parser.parse_args()

    with get_session_factory()() as session:
        if args.reclassify:
            checks = reclassify(session)
        else:
            checks = verify_locations(session, only_new=args.only_new, limit=args.limit)
        print(f"\nChecked {len(checks)}: {dict(Counter(c.status for c in checks))}")
        for c in sorted((c for c in checks if c.status != "match"), key=lambda c: -(c.distance_km or 0)):
            h = session.get(HospitalDirectory, c.hospital_id)
            km = f"{c.distance_km:.2f} km" if c.distance_km is not None else "-"
            print(f"{c.status:9} {km:>10}  {h.hospital_name}  ->  {c.google_name or '(no Google match)'}")
