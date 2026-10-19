import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// One ranked hospital from GET /hospitals/recommendations.
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
    );
  }
}

/// Ranked hospitals plus the triage level (from the last 24 h) that shaped the ranking.
class HospitalRecommendations {
  final int? triageLevelUsed;
  final double? triageAgeHours;
  final List<HospitalOption> hospitals;

  const HospitalRecommendations({
    required this.triageLevelUsed,
    required this.triageAgeHours,
    required this.hospitals,
  });
}

class HospitalService {
  /// Hospitals near [latitude]/[longitude], ranked by the backend using travel
  /// time, ED busyness and the user's triage level. [sessionId] is the triage
  /// report the user came from, if any.
  static Future<HospitalRecommendations> fetchRecommendations(
    double latitude,
    double longitude, {
    String? sessionId,
  }) async {
    final uri = Uri.parse('${ApiService.baseUrl}/hospitals/recommendations')
        .replace(queryParameters: {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'session_id': ?sessionId,
    });
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
    );
  }
}
