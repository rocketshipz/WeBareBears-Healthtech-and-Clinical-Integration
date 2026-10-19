import logging
import time
from dataclasses import dataclass
from typing import Dict, List, Optional, Sequence, Tuple

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)

ROUTE_MATRIX_URL = "https://routes.googleapis.com/distanceMatrix/v2:computeRouteMatrix"
MAX_DESTINATIONS = 25  # Route Matrix limit with one origin and traffic-aware routing

# (minutes, road km) per destination, or None when Google gave no route.
DriveTime = Optional[Tuple[int, float]]


@dataclass(frozen=True)
class Destination:
    """A hospital to route to: by Google place id when known, otherwise by coordinates."""
    key: str
    latitude: float
    longitude: float
    place_id: Optional[str] = None


FAILURE_BACKOFF_SECONDS = 60  # after a failure, skip Google for a while so each page load isn't slowed

_cache: Dict[tuple, Tuple[float, List[DriveTime]]] = {}
_failed_at: Optional[float] = None


def clear_cache() -> None:
    global _failed_at
    _cache.clear()
    _failed_at = None


def _waypoint(dest: Destination) -> dict:
    if dest.place_id:
        return {"waypoint": {"placeId": dest.place_id}}
    return {"waypoint": {"location": {"latLng": {"latitude": dest.latitude, "longitude": dest.longitude}}}}


def parse_matrix(elements: Sequence[dict], count: int) -> List[DriveTime]:
    """Route Matrix elements -> (minutes, road km) per destination index. Missing or no-route elements are None."""
    results: List[DriveTime] = [None] * count
    for el in elements:
        idx = el.get("destinationIndex", 0)
        if not 0 <= idx < count or el.get("condition") != "ROUTE_EXISTS" or "duration" not in el:
            continue
        seconds = float(str(el["duration"]).rstrip("s") or 0)
        results[idx] = (max(1, round(seconds / 60)), round(el.get("distanceMeters", 0) / 1000, 2))
    return results


def drive_times(origin_lat: float, origin_lon: float, destinations: Sequence[Destination]) -> List[DriveTime]:
    """Live-traffic driving times from the patient to each destination (one Route Matrix call).

    Returns all None (the caller keeps its estimate) when there is no key, it is disabled, or Google fails.
    """
    global _failed_at
    s = get_settings()
    destinations = list(destinations)[:MAX_DESTINATIONS]
    if not destinations or not s.ROUTING_TRAFFIC_ENABLED or not s.GOOGLE_MAPS_API_KEY:
        return [None] * len(destinations)
    if _failed_at is not None and time.monotonic() - _failed_at < FAILURE_BACKOFF_SECONDS:
        return [None] * len(destinations)

    cache_key = (round(origin_lat, 3), round(origin_lon, 3), tuple(d.key for d in destinations))
    cached = _cache.get(cache_key)
    if cached and time.monotonic() - cached[0] < s.ROUTING_TRAFFIC_CACHE_SECONDS:
        return cached[1]

    body = {
        "origins": [{"waypoint": {"location": {"latLng": {"latitude": origin_lat, "longitude": origin_lon}}}}],
        "destinations": [_waypoint(d) for d in destinations],
        "travelMode": "DRIVE",
        "routingPreference": "TRAFFIC_AWARE",
    }
    headers = {
        "X-Goog-Api-Key": s.GOOGLE_MAPS_API_KEY,
        "X-Goog-FieldMask": "originIndex,destinationIndex,duration,distanceMeters,condition",
    }
    try:
        resp = httpx.post(ROUTE_MATRIX_URL, json=body, headers=headers, timeout=s.ROUTING_TRAFFIC_TIMEOUT_SECONDS)
        resp.raise_for_status()
        results = parse_matrix(resp.json(), len(destinations))
    except Exception as e:
        detail = e.response.text[:200] if isinstance(e, httpx.HTTPStatusError) else str(e)
        logger.warning(f"[traffic] Route Matrix failed, using estimates for {FAILURE_BACKOFF_SECONDS}s: {detail}")
        _failed_at = time.monotonic()
        return [None] * len(destinations)
    _failed_at = None
    _cache[cache_key] = (time.monotonic(), results)
    return results
