import pytest
import math
from app.core.location_detector import (
    calculate_haversine_distance,
    estimate_travel_time_minutes,
    is_valid_coordinates,
    calculate_hospital_distance,
    is_private_or_loopback_ip,
    detect_ip_location,
    LocationDetector,
)


def test_is_valid_coordinates():
    assert is_valid_coordinates(3.1390, 101.6869) is True
    assert is_valid_coordinates(0.0, 0.0) is True
    assert is_valid_coordinates(-90.0, -180.0) is True
    assert is_valid_coordinates(90.0, 180.0) is True

    # Out of bounds
    assert is_valid_coordinates(91.0, 100.0) is False
    assert is_valid_coordinates(-91.0, 100.0) is False
    assert is_valid_coordinates(45.0, 181.0) is False
    assert is_valid_coordinates(45.0, -181.0) is False

    # None and invalid types
    assert is_valid_coordinates(None, 100.0) is False
    assert is_valid_coordinates(45.0, None) is False
    assert is_valid_coordinates(float("nan"), 100.0) is False
    assert is_valid_coordinates(float("inf"), 100.0) is False


def test_calculate_haversine_distance_same_point():
    # Distance from a point to itself must be 0.0
    dist = calculate_haversine_distance(3.1390, 101.6869, 3.1390, 101.6869)
    assert dist == 0.0


def test_calculate_haversine_distance_known_points():
    # Kuala Lumpur (3.1390, 101.6869) to Petaling Jaya (3.1073, 101.6067)
    # Distance is roughly 9.5 - 10.5 km
    dist = calculate_haversine_distance(3.1390, 101.6869, 3.1073, 101.6067)
    assert 9.0 <= dist <= 11.0


def test_calculate_haversine_distance_invalid_raises():
    with pytest.raises(ValueError):
        calculate_haversine_distance(999.0, 0.0, 3.0, 100.0)


def test_estimate_travel_time_minutes():
    assert estimate_travel_time_minutes(0.0) == 0
    # 35 km at 35 km/h = 1 hour = 60 minutes
    assert estimate_travel_time_minutes(35.0, average_speed_kmh=35.0) == 60
    # Small distance (>0) has at least 1 minute
    assert estimate_travel_time_minutes(0.1, average_speed_kmh=35.0) == 1


def test_calculate_hospital_distance():
    res = calculate_hospital_distance(
        patient_lat=3.1390,
        patient_lon=101.6869,
        hospital_lat=3.1490,
        hospital_lon=101.6969
    )
    assert "distance_km" in res
    assert "estimated_travel_time_minutes" in res
    assert res["distance_km"] > 0
    assert res["estimated_travel_time_minutes"] >= 1


def test_is_private_or_loopback_ip():
    assert is_private_or_loopback_ip("127.0.0.1") is True
    assert is_private_or_loopback_ip("localhost") is True
    assert is_private_or_loopback_ip("10.0.2.2") is True
    assert is_private_or_loopback_ip("192.168.1.100") is True
    assert is_private_or_loopback_ip("8.8.8.8") is False


def test_detect_ip_location_skips_private():
    # Private IPs should immediately return None without calling external network
    assert detect_ip_location("127.0.0.1") is None
    assert detect_ip_location("10.0.2.2") is None
    assert detect_ip_location("localhost") is None


def test_legacy_location_detector():
    # Tests that the legacy wrapper function signature works
    assert LocationDetector("127.0.0.1") is None
