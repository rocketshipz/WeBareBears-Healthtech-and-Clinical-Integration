"""Location detection and distance calculation utilities.

Provides accurate GPS coordinate handling, great-circle distance estimation
using the Haversine formula, travel time estimation, and client IP fallback.
"""

import ipaddress
import logging
import math
import os
from typing import Optional, Tuple, Dict, Any
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)

# Mean Earth radius in kilometers (WGS-84 standard approximation)
EARTH_RADIUS_KM = 6371.0088

# Default average urban driving speed in km/h for travel time estimation
DEFAULT_URBAN_SPEED_KMH = 35.0


def is_valid_coordinates(latitude: Optional[float], longitude: Optional[float]) -> bool:
    """Validate whether latitude and longitude are within standard geographical boundaries.
    
    Args:
        latitude: Latitude in decimal degrees (-90.0 to 90.0)
        longitude: Longitude in decimal degrees (-180.0 to 180.0)
        
    Returns:
        True if valid numbers within boundaries, False otherwise.
    """
    if latitude is None or longitude is None:
        return False
    try:
        lat = float(latitude)
        lon = float(longitude)
        if math.isnan(lat) or math.isnan(lon) or math.isinf(lat) or math.isinf(lon):
            return False
        return -90.0 <= lat <= 90.0 and -180.0 <= lon <= 180.0
    except (ValueError, TypeError):
        return False


def calculate_haversine_distance(
    lat1: float,
    lon1: float,
    lat2: float,
    lon2: float
) -> float:
    """Calculate the great-circle distance between two GPS coordinates using the Haversine formula.
    
    Args:
        lat1: Latitude of origin (decimal degrees)
        lon1: Longitude of origin (decimal degrees)
        lat2: Latitude of destination (decimal degrees)
        lon2: Longitude of destination (decimal degrees)
        
    Returns:
        Distance in kilometers, rounded to 2 decimal places.
        
    Raises:
        ValueError: If any coordinate is invalid.
    """
    if not (is_valid_coordinates(lat1, lon1) and is_valid_coordinates(lat2, lon2)):
        raise ValueError(
            f"Invalid coordinates: origin=({lat1}, {lon1}), destination=({lat2}, {lon2})"
        )

    # Convert decimal degrees to radians
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)

    # Haversine formula
    a = (
        math.sin(delta_phi / 2.0) ** 2
        + math.cos(phi1) * math.cos(phi2) * (math.sin(delta_lambda / 2.0) ** 2)
    )
    # Clamp to [0.0, 1.0] to guard against floating point inaccuracies
    a = min(1.0, max(0.0, a))
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))

    distance = EARTH_RADIUS_KM * c
    return round(distance, 2)


def estimate_travel_time_minutes(
    distance_km: float,
    average_speed_kmh: float = DEFAULT_URBAN_SPEED_KMH
) -> int:
    """Estimate driving travel time in minutes based on distance and average urban speed.
    
    Args:
        distance_km: Distance in kilometers.
        average_speed_kmh: Estimated average vehicle speed in km/h.
        
    Returns:
        Estimated travel time in minutes (minimum 1 minute if distance > 0).
    """
    if distance_km <= 0.0:
        return 0
    if average_speed_kmh <= 0:
        average_speed_kmh = DEFAULT_URBAN_SPEED_KMH

    travel_hours = distance_km / average_speed_kmh
    minutes = math.ceil(travel_hours * 60)
    return max(1, minutes)


def calculate_hospital_distance(
    patient_lat: float,
    patient_lon: float,
    hospital_lat: float,
    hospital_lon: float,
    average_speed_kmh: float = DEFAULT_URBAN_SPEED_KMH
) -> Dict[str, Any]:
    """Calculate distance and travel time from patient to a hospital.
    
    Args:
        patient_lat: Patient latitude
        patient_lon: Patient longitude
        hospital_lat: Hospital latitude
        hospital_lon: Hospital longitude
        average_speed_kmh: Speed parameter for travel time calculation
        
    Returns:
        Dict with 'distance_km' and 'estimated_travel_time_minutes'.
    """
    dist_km = calculate_haversine_distance(patient_lat, patient_lon, hospital_lat, hospital_lon)
    travel_time = estimate_travel_time_minutes(dist_km, average_speed_kmh)
    return {
        "distance_km": dist_km,
        "estimated_travel_time_minutes": travel_time
    }


def is_private_or_loopback_ip(ip_str: str) -> bool:
    """Check if the provided IP address is a private, loopback, or reserved address."""
    if not ip_str or ip_str.lower() in ["localhost", "testclient"]:
        return True
    try:
        ip_obj = ipaddress.ip_address(ip_str.strip())
        return ip_obj.is_private or ip_obj.is_loopback or ip_obj.is_reserved or ip_obj.is_link_local
    except ValueError:
        return False


def detect_ip_location(
    ip_address: Optional[str] = None
) -> Optional[Tuple[float, float]]:
    """Detect approximate geographical coordinates from a client IP address as a fallback.
    
    Note: IP geolocation is approximate (city or regional level, typically off by 5-50+ km).
    Real client GPS coordinates from the frontend should always be preferred.
    
    Args:
        ip_address: Client IP address. If None, resolves public IP if permitted.
        
    Returns:
        Tuple of (latitude, longitude) if resolved, or None.
    """
    # If a private/local IP is given (e.g. 127.0.0.1, 10.0.2.2 for Android emulator),
    # do not attempt external lookup.
    if ip_address and is_private_or_loopback_ip(ip_address):
        logger.debug(f"IP {ip_address} is local/private. Skipping external IP geolocation.")
        return None

    try:
        import geocoder  # lazy import
        target = ip_address.strip() if ip_address else "me"
        location = geocoder.ip(target)
        if location and location.latlng:
            lat, lng = location.latlng
            if is_valid_coordinates(lat, lng):
                return float(lat), float(lng)
        return None
    except Exception as e:
        logger.warning(f"Error resolving IP geolocation for target '{ip_address}': {e}")
        return None


def LocationDetector(ip: Optional[str] = None) -> Optional[Tuple[float, float]]:
    """Legacy wrapper for detecting location from IP address.
    
    Kept for backward compatibility.
    """
    return detect_ip_location(ip)


def main():
    coordinates = LocationDetector()
    if coordinates:
        latitude, longitude = coordinates
        print(f"Detected coordinates:\nLatitude: {latitude}\nLongitude: {longitude}")
    else:
        print("Could not detect coordinates from current network.")


if locAccess := os.environ.get("LOCATION_ACCESS"):
    if locAccess.lower() in ["true", "1", "yes"]:
        if __name__ == "__main__":
            main()
    else:
        if __name__ == "__main__":
            print("Location access is disabled.")
