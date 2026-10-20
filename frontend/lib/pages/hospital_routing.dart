import '../localization.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/hospital_service.dart';
import '../services/location_service.dart';
import '../theme.dart';
import '../widgets/hospital_option_card.dart';
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
    final lat =
        _currentPosition?.latitude ??
        LocationService.defaultCoordinates.latitude;
    final lon =
        _currentPosition?.longitude ??
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
        _hospitalError = 'Could not load nearby hospitals. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final report = widget.report;
    final Color outcomeColor = report?.color ?? AppColors.green;
    final IconData outcomeIcon = (report?.level ?? 5) <= 3
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
                          LocalizedText(
                            'Recommended Hospitals',
                            style: AppText.display,
                          ),
                          const SizedBox(height: 8),
                          LocalizedText(
                            'Based on your triage result and available care information.',
                            style: AppText.body,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // TRIAGE RESULT (only when opened from a report)
                    if (report != null)
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
                                child: Icon(outcomeIcon, color: outcomeColor),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LocalizedText(
                                      'Triage outcome',
                                      style: AppText.caption,
                                    ),
                                    LocalizedText(
                                      report.zoneLabel,
                                      style: AppText.style(
                                        18,
                                        FontWeight.w700,
                                        outcomeColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    LocalizedText(
                                      report.recommendation,
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
                            LocalizedText(
                              'Suggested care options',
                              style: AppText.heading,
                            ),
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
                            horizontal: 10,
                            vertical: 4,
                          ),
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
                                _currentPosition != null
                                    ? 'GPS Active'
                                    : 'Default',
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
                      LocalizedText(
                        hospitalRankingCaption(_recommendations!),
                        style: AppText.caption,
                      ),
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
                      ..._recommendations!.hospitals.asMap().entries.map((
                        entry,
                      ) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: FadeSlideIn(
                            index: 3 + entry.key,
                            child: HospitalOptionCard(hospital: entry.value),
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
          LocalizedText(
            message,
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          if (action != null) ...[const SizedBox(height: 14), action],
        ],
      ),
    );
  }
}
