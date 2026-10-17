import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Service providing client-side GPS location detection, permissions management,
/// and proximity calculation for hospitals.
class LocationService {
  /// Default fallback coordinates (Kuala Lumpur) when GPS is unavailable or denied.
  static const LatLng defaultCoordinates = LatLng(3.1390, 101.6869);

  /// Cached last detected user position for quick lookup across pages.
  static Position? _cachedPosition;

  /// Get the cached user position if available.
  static Position? get cachedPosition => _cachedPosition;

  /// Check whether device location services are enabled.
  static Future<bool> isLocationServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('[LocationService] Error checking location service: $e');
      return false;
    }
  }

  /// Request location permissions if not already granted.
  static Future<LocationPermission> requestPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission;
    } catch (e) {
      debugPrint('[LocationService] Error requesting permission: $e');
      return LocationPermission.denied;
    }
  }

  /// Fetch the user's high-accuracy GPS coordinates.
  ///
  /// Falls back to the last known position if a real-time GPS fix times out
  /// (e.g. when indoors). Returns null if permissions are denied or unavailable.
  static Future<Position?> getCurrentPosition({
    Duration timeLimit = const Duration(seconds: 10),
  }) async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location service is disabled.');
        return await _getLastKnownFallback();
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission denied ($permission).');
        return null;
      }

      // Attempt high-accuracy GPS fix with timeout
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: timeLimit,
          ),
        );
        _cachedPosition = position;
        return position;
      } catch (gpsError) {
        debugPrint('[LocationService] Real-time GPS fix failed, checking last known: $gpsError');
        return await _getLastKnownFallback();
      }
    } catch (e) {
      debugPrint('[LocationService] Unexpected error getting location: $e');
      return await _getLastKnownFallback();
    }
  }

  /// Helper to fetch last known cached position from device hardware.
  static Future<Position?> _getLastKnownFallback() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _cachedPosition = lastKnown;
      }
      return lastKnown;
    } catch (_) {
      return _cachedPosition;
    }
  }

  /// Convenience method that returns a [LatLng], using [defaultCoordinates] if GPS fails.
  static Future<LatLng> getCurrentLatLngOrDefault({
    LatLng fallback = defaultCoordinates,
  }) async {
    final position = await getCurrentPosition();
    if (position != null) {
      return LatLng(position.latitude, position.longitude);
    }
    return fallback;
  }

  /// Calculate distance in kilometers between two GPS coordinates.
  static double calculateDistanceKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    final distanceMeters = Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
    return distanceMeters / 1000.0;
  }

  /// Estimate driving travel time in minutes based on distance and average urban speed (default 35 km/h).
  static int estimateTravelTimeMinutes(
    double distanceKm, {
    double averageSpeedKmh = 35.0,
  }) {
    if (distanceKm <= 0.0) return 0;
    final hours = distanceKm / averageSpeedKmh;
    final minutes = (hours * 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  /// Format distance for UI display (e.g. "850 m" or "3.4 km").
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Format travel time for UI display (e.g. "12 min" or "1 h 15 min").
  static String formatTravelTime(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) {
      return '$hours h';
    }
    return '$hours h $remainingMinutes min';
  }
}
