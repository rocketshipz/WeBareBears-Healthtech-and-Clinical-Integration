import '../localization.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'home_page.dart';
import 'triage_report.dart';

class RecommendedHospitalsPage extends StatelessWidget {
  final TriageReportData? report;

  const RecommendedHospitalsPage({super.key, this.report});

  Future<void> _openGoogleMaps(
    String hospitalName,
  ) async {
    final String query = Uri.encodeComponent(hospitalName);

    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$query',
    );

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not open Google Maps');
    }
  }

  Future<void> _openWaze(
    String hospitalName,
  ) async {
    final String query = Uri.encodeComponent(hospitalName);

    final Uri url = Uri.parse(
      'https://waze.com/ul?q=$query&navigate=yes',
    );

    if (!await launchUrl(
      url,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not open Waze');
    }
  }

  void _showRouteOptions(
    BuildContext context,
    String hospitalName,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
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
              LocalizedText(hospitalName, style: AppText.caption),
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

                    LocalizedText('Suggested care options', style: AppText.heading),
                    const SizedBox(height: 4),
                    LocalizedText(
                      'Sample data is shown for the prototype.',
                      style: AppText.caption,
                    ),

                    const SizedBox(height: 14),

                    FadeSlideIn(
                      index: 3,
                      child: _hospitalCard(
                        context: context,
                        badge: 'Best match',
                        hospitalName: 'Central General Hospital',
                        distance: '2.3 km',
                        travelTime: '8 min',
                        waitingTime: '30 min',
                        emptyBeds: '12',
                        registeredPatients: '36',
                      ),
                    ),

                    const SizedBox(height: 14),

                    FadeSlideIn(
                      index: 4,
                      child: _hospitalCard(
                        context: context,
                        badge: 'Shortest wait',
                        hospitalName: 'Riverside Medical Centre',
                        distance: '5.1 km',
                        travelTime: '15 min',
                        waitingTime: '15 min',
                        emptyBeds: '8',
                        registeredPatients: '28',
                      ),
                    ),

                    const SizedBox(height: 14),

                    FadeSlideIn(
                      index: 5,
                      child: _hospitalCard(
                        context: context,
                        badge: 'Closest',
                        hospitalName: 'Maple Community Hospital',
                        distance: '1.2 km',
                        travelTime: '5 min',
                        waitingTime: '45 min',
                        emptyBeds: '6',
                        registeredPatients: '42',
                      ),
                    ),

                    const SizedBox(height: 18),

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
            child: LocalizedText(
              badge,
              style: AppText.style(12, FontWeight.w700, AppColors.darkTeal),
            ),
          ),

          const SizedBox(height: 12),

          LocalizedText(hospitalName, style: AppText.heading),

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