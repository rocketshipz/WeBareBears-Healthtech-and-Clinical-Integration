import httpx
import pytest

from app.core.config import get_settings
from app.services import traffic_service
from app.services.traffic_service import Destination, drive_times, parse_matrix

DESTS = [Destination("A", 3.15, 101.69), Destination("B", 3.16, 101.70, place_id="place-b")]
MATRIX = [
    {"originIndex": 0, "destinationIndex": 1, "duration": "754s", "distanceMeters": 6420, "condition": "ROUTE_EXISTS"},
    {"originIndex": 0, "destinationIndex": 0, "condition": "ROUTE_NOT_FOUND"},
]


@pytest.fixture
def maps_on(monkeypatch):
    s = get_settings()
    monkeypatch.setattr(s, "GOOGLE_MAPS_API_KEY", "test-key")
    monkeypatch.setattr(s, "ROUTING_TRAFFIC_ENABLED", True)
    traffic_service.clear_cache()
    yield
    traffic_service.clear_cache()


def fake_post(calls, status=200, payload=MATRIX, exc=None):
    def post(url, json=None, headers=None, timeout=None):
        calls.append(json)
        if exc:
            raise exc
        return httpx.Response(status, json=payload, request=httpx.Request("POST", url))
    return post


def test_parse_matrix():
    assert parse_matrix(MATRIX, 2) == [None, (13, 6.42)]
    assert parse_matrix([{"destinationIndex": 5, "duration": "60s", "condition": "ROUTE_EXISTS"}], 2) == [None, None]


def test_disabled_without_key_makes_no_call(monkeypatch):
    calls = []
    monkeypatch.setattr(traffic_service.httpx, "post", fake_post(calls))
    traffic_service.clear_cache()
    assert drive_times(3.139, 101.687, DESTS) == [None, None] and calls == []


def test_calls_google_once_and_caches(monkeypatch, maps_on):
    calls = []
    monkeypatch.setattr(traffic_service.httpx, "post", fake_post(calls))
    assert drive_times(3.139, 101.687, DESTS) == [None, (13, 6.42)]
    assert drive_times(3.1391, 101.6871, DESTS) == [None, (13, 6.42)]  # same ~100 m cell -> cached
    assert len(calls) == 1
    body = calls[0]
    assert body["routingPreference"] == "TRAFFIC_AWARE"
    assert body["destinations"][1] == {"waypoint": {"placeId": "place-b"}}
    assert "location" in body["destinations"][0]["waypoint"]


@pytest.mark.parametrize("kwargs", [{"status": 403, "payload": {"error": {"message": "billing"}}},
                                    {"exc": httpx.TimeoutException("slow")}])
def test_failure_falls_back_and_backs_off(monkeypatch, maps_on, kwargs):
    calls = []
    monkeypatch.setattr(traffic_service.httpx, "post", fake_post(calls, **kwargs))
    assert drive_times(3.139, 101.687, DESTS) == [None, None]
    assert drive_times(3.5, 101.5, DESTS) == [None, None]
    assert len(calls) == 1  # second request skipped during the back-off
