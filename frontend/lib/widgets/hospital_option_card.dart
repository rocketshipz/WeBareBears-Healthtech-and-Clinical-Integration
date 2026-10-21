import '../localization.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/hospital_service.dart';
import '../services/location_service.dart';
import '../theme.dart';

/// One line explaining what shaped the ranking (the triage level from the last 24 h, if any).
String hospitalRankingCaption(HospitalRecommendations recommendations) {
  final level = recommendations.triageLevelUsed;
  if (level == null) {
    if (recommendations.clinics.isNotEmpty) {
      return 'No recent triage. Hospitals are ranked by travel time and how busy '
          'each emergency department is. Clinics are ranked by travel time and opening hours.';
    }
    return 'No triage in the last 24 hours. Ranked by distance and how busy each emergency department is.';
  }
  final hours = recommendations.triageAgeHours ?? 0;
  final ago = hours < 1 ? 'less than an hour ago' : '${hours.round()} h ago';
  if (recommendations.hospitals.any((h) => h.isClinic)) {
    return 'Ranked for your Level $level triage result ($ago). A walk-in clinic '
        'is suitable. The emergency department is listed in case symptoms get worse.';
  }
  return 'Ranked for your Level $level triage result ($ago).';
}

/// A ranked hospital or clinic: badges, ED activity or opening hours, travel time and a "View Route" button.
class HospitalOptionCard extends StatelessWidget {
  final HospitalOption hospital;

  const HospitalOptionCard({super.key, required this.hospital});

  Future<void> _openGoogleMaps() async {
    // The exact Google place when the location check found it; otherwise
    // Google's own search for name + address (safer than a possibly wrong coordinate).
    final placeId = hospital.googlePlaceId;
    final Uri url = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      if (placeId != null) ...{
        'query': hospital.name,
        'query_place_id': placeId,
      } else
        'query': [
          hospital.name,
          hospital.address,
        ].where((s) => s.isNotEmpty).join(', '),
    });

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open Google Maps');
    }
  }

  Future<void> _openWaze() async {
    final Uri url = Uri.parse(
      'https://waze.com/ul?ll=${hospital.latitude},${hospital.longitude}'
      '&navigate=yes',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open Waze');
    }
  }

  void _showRouteOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              LocalizedText('Open route with', style: AppText.heading),
              const SizedBox(height: 4),
              LocalizedText(hospital.name, style: AppText.caption),
              const SizedBox(height: 14),
              _routeTile(
                icon: Icons.map_outlined,
                title: 'Google Maps',
                onTap: () {
                  Navigator.pop(context);
                  _openGoogleMaps();
                },
              ),
              const SizedBox(height: 10),
              _routeTile(
                icon: Icons.navigation_outlined,
                title: 'Waze',
                onTap: () {
                  Navigator.pop(context);
                  _openWaze();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _routeTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.field,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: AppColors.paleTeal,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.darkTeal, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(child: LocalizedText(title, style: AppText.bodyStrong)),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: AppColors.grey,
            ),
          ],
        ),
      ),
    );
  }

  /// Capitalised label, e.g. "Very busy" for ED activity or "Private" for a clinic type.
  String _capitalised(String? value) {
    if (value == null || value.isEmpty) return 'Unknown';
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final distance = LocationService.formatDistance(
      hospital.roadDistanceKm ?? hospital.distanceKm,
    );
    final travelTime = LocationService.formatTravelTime(hospital.travelMinutes);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BADGES
          if (hospital.badges.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final badge in hospital.badges)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.paleTeal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: LocalizedText(
                      badge,
                      style: AppText.style(
                        12,
                        FontWeight.w700,
                        AppColors.darkTeal,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          LocalizedText(hospital.name, style: AppText.heading),

          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.grey,
              ),
              const SizedBox(width: 4),
              LocalizedText('$distance away', style: AppText.caption),
              const SizedBox(width: 8),
              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: AppColors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              LocalizedText(travelTime, style: AppText.caption),
            ],
          ),

          const SizedBox(height: 16),

          // INFORMATION
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.field,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                if (hospital.isClinic) ...[
                  Expanded(
                    child: _infoItem(
                      icon: Icons.storefront_outlined,
                      value: _capitalised(
                        hospital.openStatus == 'open'
                            ? 'open now'
                            : 'call ahead',
                      ),
                      label: hospital.openStatus == 'open'
                          ? 'Google hours'
                          : 'Hours not verified',
                    ),
                  ),
                  Expanded(
                    child: _infoItem(
                      icon: Icons.medical_services_outlined,
                      value: _capitalised(hospital.clinicType),
                      label: 'Clinic',
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _infoItem(
                      icon: Icons.local_hospital_outlined,
                      value: _capitalised(hospital.activityLevel),
                      label: 'ED activity',
                    ),
                  ),
                  Expanded(
                    child: _infoItem(
                      icon: Icons.bed_outlined,
                      value: hospital.availableEdSpaces?.toString() ?? '-',
                      label: 'ED spaces free',
                    ),
                  ),
                ],
                Expanded(
                  child: _infoItem(
                    icon: hospital.liveTraffic
                        ? Icons.traffic_outlined
                        : Icons.schedule_rounded,
                    value: travelTime,
                    label: hospital.liveTraffic
                        ? 'Live traffic'
                        : 'Est. travel',
                  ),
                ),
              ],
            ),
          ),

          if (hospital.reason.isNotEmpty) ...[
            const SizedBox(height: 10),
            LocalizedText(hospital.reason, style: AppText.caption),
          ],

          const SizedBox(height: 16),

          PrimaryButton(
            label: 'View Route',
            icon: Icons.navigation_outlined,
            onPressed: () {
              _showRouteOptions(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _infoItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, size: 21, color: AppColors.teal),
        const SizedBox(height: 6),
        LocalizedText(
          value,
          textAlign: TextAlign.center,
          style: AppText.bodyStrong,
        ),
        LocalizedText(
          label,
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ],
    );
  }
}
