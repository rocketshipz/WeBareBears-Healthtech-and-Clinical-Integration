"""QC Level 4-5 clinic routing: `python scripts/nearby_clinics.py 4.5975 101.0901` from backend/.

Lists every clinic_data row near a point (nearest first), whether routing keeps or skips it and why, the stored
opening hours status, and which clinics the app would recommend. Read-only and no Google calls unless --lookup.
Options: --radius KM (default 5), --level 4|5, --at "2026-10-21 21:30" (Malaysia time), --lookup, --all.
"""
import argparse
import logging
import sys
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.database import get_session_factory  # noqa: E402
from app.core.location_detector import calculate_haversine_distance, is_valid_coordinates  # noqa: E402
from app.models.clinic_directory import ClinicDirectory  # noqa: E402
from app.models.clinic_place_check import ClinicPlaceCheck  # noqa: E402
from app.repositories.clinic_repository import (  # noqa: E402
    CHECK_VERSION, GP_CATEGORIES, RURAL_CATEGORY, ClinicRepository, is_walk_in_gp,
)
from app.schemas.hospital import Coordinates  # noqa: E402
from app.services import clinic_hours_service  # noqa: E402
from app.services.clinic_hours_service import MALAYSIA_TZ, stored_hours  # noqa: E402
from app.services.routing_service import rank_clinics  # noqa: E402


def _coord(value):
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def skip_reason(clinic: ClinicDirectory, lat, lon) -> str:
    if lat is None or lon is None or not is_valid_coordinates(lat, lon):
        return "no coordinates"
    if clinic.clinic_category not in GP_CATEGORIES | {RURAL_CATEGORY}:
        return f"category {clinic.clinic_category}"
    if not is_walk_in_gp(clinic.clinic_name):
        return "specialist name"
    return ""


if __name__ == "__main__":
    logging.basicConfig(level=logging.WARNING)
    parser = argparse.ArgumentParser()
    parser.add_argument("lat", type=float)
    parser.add_argument("lon", type=float)
    parser.add_argument("--radius", type=float, default=5.0, help="km to list (default 5)")
    parser.add_argument("--level", type=int, default=4, choices=(4, 5))
    parser.add_argument("--at", default=None, help='Malaysia local time to check hours at, e.g. "2026-10-21 21:30"')
    parser.add_argument("--lookup", action="store_true",
                        help="fetch missing hours from Google first, as the app does (paid calls)")
    parser.add_argument("--all", action="store_true", help="also list skipped clinics (default: kept only)")
    args = parser.parse_args()

    now = (datetime.strptime(args.at, "%Y-%m-%d %H:%M").replace(tzinfo=MALAYSIA_TZ) if args.at
           else datetime.now(MALAYSIA_TZ))
    me = Coordinates(latitude=args.lat, longitude=args.lon)

    with get_session_factory()() as session:
        # What the app would recommend (same ranking; live traffic is not used here).
        rows = ClinicRepository(session).list_routable()
        hours_fn = ((lambda rs: clinic_hours_service.hours_for(rs, now)) if args.lookup
                    else (lambda rs: stored_hours(rs, now)))
        picks = rank_clinics(rows, me, args.level, limit=4, hours_fn=hours_fn)
        picked = {r.hospital.hospital_id: i for i, r in enumerate(picks, 1)}
        routable = {r.clinic_code: r for r in rows if r.routable}

        checks = {c.clinic_code: c for c in session.query(ClinicPlaceCheck)}
        listed = []
        for clinic in session.query(ClinicDirectory):
            lat, lon = _coord(clinic.latitude), _coord(clinic.longitude)
            if lat is None or lon is None:
                continue
            km = calculate_haversine_distance(args.lat, args.lon, lat, lon)
            if km <= args.radius:
                listed.append((km, clinic, skip_reason(clinic, lat, lon)))

    def km_to(check):
        return calculate_haversine_distance(args.lat, args.lon, check.google_latitude, check.google_longitude)

    listed.sort(key=lambda x: x[0])
    print(f"Clinics within {args.radius} km of {args.lat}, {args.lon} at {now:%a %d %b %H:%M} (Malaysia), "
          f"Level {args.level}:\n")
    print(f"{'pick':>4} {'km':>5}  {'hours':9} {'google':10} {'type':7} {'category':21} name / note")
    shown = 0
    for km, clinic, reason in listed:
        if reason and not args.all:
            continue
        row, check = routable.get(clinic.clinic_code), checks.get(clinic.clinic_code)
        hours = stored_hours([row], now)[row.clinic_code] if row else "-"
        google = check.status if check else "unchecked"
        pick = f"#{picked[clinic.clinic_code]}" if clinic.clinic_code in picked else ""
        note = f"  [skipped: {reason}]" if reason else ""
        if check is not None and check.check_version != CHECK_VERSION:
            google = "old-rules"  # redone the next time it is shortlisted, or with check_clinic_hours.py --only-new
        elif check is not None and check.status == "not_gp":
            note += f"  [skipped: Google lists it as {', '.join(check.google_types or [])}]"
        elif check is not None and check.status == "mismatch":
            note += f"  [DB coordinate wrong: Google puts it {km_to(check):.1f} km away, at {check.google_address}]"
        if check is not None and check.status in ("uncertain", "not_gp") and check.google_name:
            note += f"  [Google found: {check.google_name}]"
        print(f"{pick:>4} {km:5.2f}  {hours:9} {google:10} {(clinic.clinic_type or '-'):7} "
              f"{(clinic.clinic_category or '-'):21} {clinic.clinic_name}{note}")
        shown += 1
    skipped = sum(1 for _, _, r in listed if r)
    print(f"\n{shown} listed, {skipped} skipped by the filters" + ("" if args.all else " (show them with --all)") + ".")
    if not picks:
        print("No clinic would be recommended: the app falls back to the hospital list.")
    print("hours: open / closed / unknown (no usable Google hours) / gone (closed down) / excluded. "
          "Only open and unknown clinics can be picked.\n"
          "google: match / mismatch (DB coordinate wrong, Google's used) / uncertain (maybe another branch: "
          "not used) / not_gp / not_found / old-rules (checked before the current rules: not used yet) / unchecked.")
