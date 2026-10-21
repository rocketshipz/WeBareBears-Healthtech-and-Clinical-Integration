import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// One ranked hospital or (for Level 4-5) walk-in clinic from GET /hospitals/recommendations.
class HospitalOption {
  final String id;
  final String name;
  final List<String> badges;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final int travelMinutes;

  /// ED activity: low, moderate, busy or very busy (null when unknown).
  final String? activityLevel;
  final int? availableEdSpaces;
  final String reason;
  final String address;

  /// Google place of the hospital (from the location check), for exact navigation.
  final String? googlePlaceId;

  /// True when [travelMinutes] is Google's live-traffic driving time, not the estimate.
  final bool liveTraffic;

  /// Driving distance, set only with live traffic.
  final double? roadDistanceKm;

  /// True for a walk-in clinic (no emergency department).
  final bool isClinic;

  /// Clinics only: public or private.
  final String? clinicType;

  /// Clinics only: open (confirmed by Google opening hours) or unknown.
  final String? openStatus;

  const HospitalOption({
    required this.id,
    required this.name,
    required this.badges,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    required this.travelMinutes,
    required this.activityLevel,
    required this.availableEdSpaces,
    required this.reason,
    this.address = '',
    this.googlePlaceId,
    this.liveTraffic = false,
    this.roadDistanceKm,
    this.isClinic = false,
    this.clinicType,
    this.openStatus,
  });

  factory HospitalOption.fromJson(Map<String, dynamic> json) {
    final hospital = json['hospital'] as Map<String, dynamic>;
    final location = hospital['location'] as Map<String, dynamic>;
    return HospitalOption(
      id: hospital['hospital_id'].toString(),
      name: hospital['name'].toString(),
      badges: (json['badges'] as List? ?? []).map((e) => e.toString()).toList(),
      latitude: (location['latitude'] as num).toDouble(),
      longitude: (location['longitude'] as num).toDouble(),
      distanceKm: (json['distance_km'] as num).toDouble(),
      travelMinutes: (json['estimated_travel_time_minutes'] as num).toInt(),
      activityLevel: hospital['activity_level'] as String?,
      availableEdSpaces: (hospital['available_ed_spaces'] as num?)?.toInt(),
      reason: (json['recommendation_reason'] ?? '').toString(),
      address: (hospital['address'] ?? '').toString(),
      googlePlaceId: hospital['google_place_id'] as String?,
      liveTraffic: json['travel_time_source'] == 'traffic',
      roadDistanceKm: (json['road_distance_km'] as num?)?.toDouble(),
      isClinic: hospital['facility_type'] == 'clinic',
      clinicType: hospital['clinic_type'] as String?,
      openStatus: hospital['open_status'] as String?,
    );
  }
}

/// Ranked hospitals plus the triage level (from the last 24 h) that shaped the ranking.
class HospitalRecommendations {
  final int? triageLevelUsed;
  final double? triageAgeHours;
  final List<HospitalOption> hospitals;

  /// Walk-in clinics ranked separately, only when there is no recent triage
  /// and clinics were requested.
  final List<HospitalOption> clinics;

  const HospitalRecommendations({
    required this.triageLevelUsed,
    required this.triageAgeHours,
    required this.hospitals,
    this.clinics = const [],
  });
}

class HospitalService {
  /// Hospitals near [latitude]/[longitude], ranked by the backend using travel
  /// time, ED busyness and the user's triage level. [sessionId] is the triage
  /// report the user came from, if any. [limit] is how many to return (backend default 5).
  /// [clinics]: with no recent triage, also rank this many walk-in clinics (separate list).
  static Future<HospitalRecommendations> fetchRecommendations(
    double latitude,
    double longitude, {
    String? sessionId,
    int? limit,
    int? clinics,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/hospitals/recommendations')
        .replace(
          queryParameters: {
            'lat': latitude.toString(),
            'lon': longitude.toString(),
            'session_id': ?sessionId,
            'limit': ?limit?.toString(),
            'clinics': ?clinics?.toString(),
          },
        );
    final res = await http
        .get(uri, headers: ApiService.defaultHeaders)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Hospital service error (${res.statusCode})');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>;
    return HospitalRecommendations(
      triageLevelUsed: (data['triage_level_used'] as num?)?.toInt(),
      triageAgeHours: (data['triage_age_hours'] as num?)?.toDouble(),
      hospitals: (data['recommendations'] as List)
          .map((e) => HospitalOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      clinics: (data['clinic_recommendations'] as List? ?? [])
          .map((e) => HospitalOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Stops the user's recent triage result from shaping the ranking (the
  /// triage report itself is kept). Needs a logged-in user.
  static Future<void> clearRecentTriage() async {
    final res = await http
        .delete(
          Uri.parse('${ApiService.baseUrl}/hospitals/triage-context'),
          headers: ApiService.defaultHeaders,
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Could not clear triage result (${res.statusCode})');
    }
  }
}
