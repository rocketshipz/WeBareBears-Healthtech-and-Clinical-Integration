import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';
import '../theme.dart';
import 'home_page.dart';
import 'triage_report.dart';

/// Representation of a hospital facility with geographical coordinates.
class HospitalOption {
  final String name;
  final String badge;
  final double latitude;
  final double longitude;
  final String waitingTime;
  final String emptyBeds;
  final String registeredPatients;

  const HospitalOption({
    required this.name,
    required this.badge,
    required this.latitude,
    required this.longitude,
    required this.waitingTime,
    required this.emptyBeds,
    required this.registeredPatients,
  });
}

class RecommendedHospitalsPage extends StatefulWidget {
  final TriageReportData? report;

  const RecommendedHospitalsPage({super.key, this.report});

  @override
  State<RecommendedHospitalsPage> createState() =>
      _RecommendedHospitalsPageState();
}

class _RecommendedHospitalsPageState extends State<RecommendedHospitalsPage> {
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  // Hospital options. Coordinate values can be customized or replaced with real backend data.
  final List<HospitalOption> _hospitals = const [
    HospitalOption(
      name: 'Central General Hospital',
      badge: 'Best match',
      latitude: 3.1470,
      longitude: 101.6910,
      waitingTime: '30 min',
      emptyBeds: '12',
      registeredPatients: '36',
    ),
    HospitalOption(
      name: 'Riverside Medical Centre',
      badge: 'Shortest wait',
      latitude: 3.1650,
      longitude: 101.7100,
      waitingTime: '15 min',
      emptyBeds: '8',
      registeredPatients: '28',
    ),
    HospitalOption(
      name: 'Maple Community Hospital',
      badge: 'Closest',
      latitude: 3.1310,
      longitude: 101.6820,
      waitingTime: '45 min',
      emptyBeds: '6',
      registeredPatients: '42',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    try {
      final position = await LocationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _openGoogleMaps(String hospitalName) async {
    final String query = Uri.encodeComponent(hospitalName);
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open Google Maps');
    }
  }

  Future<void> _openWaze(String hospitalName) async {
    final String query = Uri.encodeComponent(hospitalName);
    final Uri url = Uri.parse(
      'https://waze.com/ul?q=$query&navigate=yes',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open Waze');
    }
  }

  void _showRouteOptions(BuildContext context, String hospitalName) {
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
              Text('Open route with', style: AppText.heading),
              const SizedBox(height: 4),
              Text(hospitalName, style: AppText.caption),
              const SizedBox(height: 14),
              _routeTile(
                icon: Icons.map_outlined,
                title: 'Google Maps',
                onTap: () {
                  Navigator.pop(context);
                  _openGoogleMaps(hospitalName);
                },
              ),
              const SizedBox(height: 10),
              _routeTile(
                icon: Icons.navigation_outlined,
                title: 'Waze',
                onTap: () {
                  Navigator.pop(context);
                  _openWaze(hospitalName);
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
            Expanded(child: Text(title, style: AppText.bodyStrong)),
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

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final Color outcomeColor = report?.color ?? AppColors.green;
    final IconData outcomeIcon = (report?.level ?? 4) <= 3
        ? Icons.priority_high_rounded
        : Icons.check_rounded;

    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onSelected: (index) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => MainNavigation(initialIndex: index),
            ),
            (route) => false,
          );
        },
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BAR
                    FadeSlideIn(
                      index: 0,
                      child: Row(
                        children: [
                          CircleBackButton(
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 14),
                          const BrandWordmark(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // PAGE TITLE
                    FadeSlideIn(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recommended Hospitals',
                              style: AppText.display),
                          const SizedBox(height: 8),
                          Text(
                            'Based on your triage result and available care information.',
                            style: AppText.body,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // TRIAGE RESULT
                    FadeSlideIn(
                      index: 2,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: outcomeColor.withValues(alpha: 0.25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: outcomeColor.withValues(alpha: 0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: outcomeColor.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                outcomeIcon,
                                color: outcomeColor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Triage outcome',
                                      style: AppText.caption),
                                  Text(
                                    report?.zoneLabel ?? 'Green Zone · Level 4',
                                    style: AppText.style(
                                      18,
                                      FontWeight.w700,
                                      outcomeColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    report?.recommendation ??
                                        'Your screening indicates a non-critical case. '
                                            'You may consider facilities with a shorter waiting time.',
                                    style: AppText.body,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Suggested care options',
                                style: AppText.heading),
                            const SizedBox(height: 4),
                            Text(
                              _isLoadingLocation
                                  ? 'Acquiring GPS location...'
                                  : _currentPosition != null
                                      ? 'Distances calculated from your live GPS.'
                                      : 'Using regional baseline coordinates.',
                              style: AppText.caption,
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _currentPosition != null
                                ? AppColors.paleTeal
                                : AppColors.field,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                size: 14,
                                color: _currentPosition != null
                                    ? AppColors.darkTeal
                                    : AppColors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _currentPosition != null ? 'GPS Active' : 'Default',
                                style: AppText.style(
                                  11,
                                  FontWeight.w600,
                                  _currentPosition != null
                                      ? AppColors.darkTeal
                                      : AppColors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // RENDER DYNAMIC HOSPITAL CARDS
                    ..._hospitals.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final HospitalOption hospital = entry.value;

                      // Calculate dynamic distance and travel time
                      final userLat = _currentPosition?.latitude ??
                          LocationService.defaultCoordinates.latitude;
                      final userLon = _currentPosition?.longitude ??
                          LocationService.defaultCoordinates.longitude;

                      final distanceKm = LocationService.calculateDistanceKm(
                        startLatitude: userLat,
                        startLongitude: userLon,
                        endLatitude: hospital.latitude,
                        endLongitude: hospital.longitude,
                      );

                      final travelMinutes =
                          LocationService.estimateTravelTimeMinutes(distanceKm);
                      final distanceLabel =
                          LocationService.formatDistance(distanceKm);
                      final travelLabel =
                          LocationService.formatTravelTime(travelMinutes);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: FadeSlideIn(
                          index: 3 + index,
                          child: _hospitalCard(
                            context: context,
                            badge: hospital.badge,
                            hospitalName: hospital.name,
                            distance: distanceLabel,
                            travelTime: travelLabel,
                            waitingTime: hospital.waitingTime,
                            emptyBeds: hospital.emptyBeds,
                            registeredPatients: hospital.registeredPatients,
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 10),

                    // DISCLAIMER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.teal,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'If your symptoms become severe or you develop '
                              'emergency warning signs, seek emergency care immediately.',
                              style: AppText.caption,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _hospitalCard({
    required BuildContext context,
    required String badge,
    required String hospitalName,
    required String distance,
    required String travelTime,
    required String waitingTime,
    required String emptyBeds,
    required String registeredPatients,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // BADGE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.paleTeal,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: AppText.style(12, FontWeight.w700, AppColors.darkTeal),
            ),
          ),

          const SizedBox(height: 12),

          Text(hospitalName, style: AppText.heading),

          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.grey,
              ),
              const SizedBox(width: 4),
              Text('$distance away', style: AppText.caption),
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
              Text(travelTime, style: AppText.caption),
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
                Expanded(
                  child: _infoItem(
                    icon: Icons.schedule_rounded,
                    value: waitingTime,
                    label: 'Est. wait',
                  ),
                ),
                Expanded(
                  child: _infoItem(
                    icon: Icons.bed_outlined,
                    value: emptyBeds,
                    label: 'Empty beds',
                  ),
                ),
                Expanded(
                  child: _infoItem(
                    icon: Icons.people_outline_rounded,
                    value: registeredPatients,
                    label: 'Patients',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          PrimaryButton(
            label: 'View Route',
            icon: Icons.navigation_outlined,
            onPressed: () {
              _showRouteOptions(
                context,
                hospitalName,
              );
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
        Text(
          value,
          textAlign: TextAlign.center,
          style: AppText.bodyStrong,
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ],
    );
  }
}