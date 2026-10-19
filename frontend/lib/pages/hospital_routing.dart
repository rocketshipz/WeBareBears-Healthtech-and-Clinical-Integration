import '../localization.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/hospital_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import 'home_page.dart';
import 'triage_report.dart';

class RecommendedHospitalsPage extends StatefulWidget {
  final TriageReportData? report;

  /// Stored triage report the user came from, so the ranking uses that level.
  final String? sessionId;

  const RecommendedHospitalsPage({super.key, this.report, this.sessionId});

  @override
  State<RecommendedHospitalsPage> createState() =>
      _RecommendedHospitalsPageState();
}

class _RecommendedHospitalsPageState extends State<RecommendedHospitalsPage> {
  Position? _currentPosition;
  bool _isLoadingLocation = true;

  // Ranked by the backend (distance, ED busyness and the triage level from the last 24 h).
  HospitalRecommendations? _recommendations;
  bool _isLoadingHospitals = true;
  String? _hospitalError;

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
    await _loadHospitals();
  }

  Future<void> _loadHospitals() async {
    setState(() {
      _isLoadingHospitals = true;
      _hospitalError = null;
    });
    final lat = _currentPosition?.latitude ??
        LocationService.defaultCoordinates.latitude;
    final lon = _currentPosition?.longitude ??
        LocationService.defaultCoordinates.longitude;
    try {
      final result = await HospitalService.fetchRecommendations(
        lat,
        lon,
        sessionId: widget.sessionId,
      );
      if (!mounted) return;
      setState(() {
        _recommendations = result;
        _isLoadingHospitals = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingHospitals = false;
        _hospitalError =
            'Could not load nearby hospitals. Please try again.';
      });
    }
  }

  String get _rankingCaption {
    final level = _recommendations?.triageLevelUsed;
    if (level == null) {
      return 'No triage in the last 24 hours. Ranked by distance and how busy each emergency department is.';
    }
    final hours = _recommendations?.triageAgeHours ?? 0;
    final ago = hours < 1 ? 'less than an hour ago' : '${hours.round()} h ago';
    return 'Ranked for your Level $level triage result ($ago).';
  }

  Future<void> _openGoogleMaps(HospitalOption hospital) async {
    // The exact Google place when the location check found it; otherwise
    // Google's own search for name + address (safer than a possibly wrong coordinate).
    final placeId = hospital.googlePlaceId;
    final Uri url = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      if (placeId != null) ...{
        'query': hospital.name,
        'query_place_id': placeId,
      } else
        'query': [hospital.name, hospital.address]
            .where((s) => s.isNotEmpty)
            .join(', '),
    });

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open Google Maps');
    }
  }

  Future<void> _openWaze(HospitalOption hospital) async {
    final Uri url = Uri.parse(
      'https://waze.com/ul?ll=${hospital.latitude},${hospital.longitude}'
      '&navigate=yes',
    );

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open Waze');
    }
  }

  void _showRouteOptions(BuildContext context, HospitalOption hospital) {
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
                  _openGoogleMaps(hospital);
                },
              ),
              const SizedBox(height: 10),
              _routeTile(
                icon: Icons.navigation_outlined,
                title: 'Waze',
                onTap: () {
                  Navigator.pop(context);
                  _openWaze(hospital);
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

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
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
                          LocalizedText('Recommended Hospitals',
                              style: AppText.display),
                          const SizedBox(height: 8),
                          LocalizedText(
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
                                  LocalizedText('Triage outcome',
                                      style: AppText.caption),
                                  LocalizedText(
                                    report?.zoneLabel ?? 'Green Zone · Level 4',
                                    style: AppText.style(
                                      18,
                                      FontWeight.w700,
                                      outcomeColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  LocalizedText(
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
                            LocalizedText('Suggested care options',
                                style: AppText.heading),
                            const SizedBox(height: 4),
                            LocalizedText(
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
                              LocalizedText(
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

                    if (_recommendations != null) ...[
                      const SizedBox(height: 8),
                      LocalizedText(_rankingCaption, style: AppText.caption),
                    ],

                    const SizedBox(height: 14),

                    if (_isLoadingLocation || _isLoadingHospitals)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_hospitalError != null)
                      _statusMessage(
                        _hospitalError!,
                        action: PrimaryButton(
                          label: 'Try again',
                          icon: Icons.refresh_rounded,
                          onPressed: _loadHospitals,
                        ),
                      )
                    else if (_recommendations!.hospitals.isEmpty)
                      _statusMessage('No hospitals found near you.')
                    else
                      // RENDER RANKED HOSPITAL CARDS
                      ..._recommendations!.hospitals.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: FadeSlideIn(
                            index: 3 + entry.key,
                            child: _hospitalCard(
                              context: context,
                              hospital: entry.value,
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
                            child: LocalizedText(
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

  Widget _statusMessage(String message, {Widget? action}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        children: [
          LocalizedText(message,
              textAlign: TextAlign.center, style: AppText.body),
          if (action != null) ...[const SizedBox(height: 14), action],
        ],
      ),
    );
  }

  /// Capitalised ED activity label, e.g. "Very busy".
  String _activityLabel(String? level) {
    if (level == null || level.isEmpty) return 'Unknown';
    return level[0].toUpperCase() + level.substring(1);
  }

  Widget _hospitalCard({
    required BuildContext context,
    required HospitalOption hospital,
  }) {
    final distance = LocationService.formatDistance(
        hospital.roadDistanceKm ?? hospital.distanceKm);
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.paleTeal,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: LocalizedText(
                      badge,
                      style:
                          AppText.style(12, FontWeight.w700, AppColors.darkTeal),
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
                Expanded(
                  child: _infoItem(
                    icon: Icons.local_hospital_outlined,
                    value: _activityLabel(hospital.activityLevel),
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
                Expanded(
                  child: _infoItem(
                    icon: hospital.liveTraffic
                        ? Icons.traffic_outlined
                        : Icons.schedule_rounded,
                    value: travelTime,
                    label: hospital.liveTraffic ? 'Live traffic' : 'Est. travel',
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
              _showRouteOptions(context, hospital);
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