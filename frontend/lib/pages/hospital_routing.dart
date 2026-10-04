import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class RecommendedHospitalsPage extends StatelessWidget {
  const RecommendedHospitalsPage({super.key});

  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color background = Color(0xFFF7FBFB);
  static const Color lightTeal = Color(0xFFE4F7F6);
  static const Color border = Color(0xFFE3ECEC);
  static const Color green = Color(0xFF2E9E70);

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
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(
                  bottom: 20,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7E1E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const Text(
                'Open route with',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: darkTeal,
                ),
              ),

              const SizedBox(height: 18),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: lightTeal,
                  child: Icon(
                    Icons.map_outlined,
                    color: darkTeal,
                  ),
                ),
                title: const Text(
                  'Google Maps',
                  style: TextStyle(
                    fontFamily: 'Helvetica',
                    fontWeight: FontWeight.w600,
                    color: darkTeal,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: grey,
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openGoogleMaps(hospitalName);
                },
              ),

              const Divider(),

              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: lightTeal,
                  child: Icon(
                    Icons.navigation_outlined,
                    color: darkTeal,
                  ),
                ),
                title: const Text(
                  'Waze',
                  style: TextStyle(
                    fontFamily: 'Helvetica',
                    fontWeight: FontWeight.w600,
                    color: darkTeal,
                  ),
                ),
                trailing: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: grey,
                ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            30,
          ),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 600,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // TOP BAR
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: darkTeal,
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),

                      const SizedBox(width: 4),

                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text: 'Triage',
                              style: TextStyle(
                                color: darkTeal,
                              ),
                            ),
                            TextSpan(
                              text: 'MY',
                              style: TextStyle(
                                color: teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // PAGE TITLE
                  const Text(
                    'Recommended Hospitals',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'Based on your triage result and available care information.',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 14,
                      height: 1.4,
                      color: grey,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // TRIAGE RESULT
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),

                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FAF6),
                      borderRadius:
                          BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFD8EEE4),
                      ),
                    ),

                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              Color(0xFFDDF4E8),
                          child: Icon(
                            Icons.check_rounded,
                            color: green,
                          ),
                        ),

                        SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Triage outcome',
                                style: TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 12,
                                  color: grey,
                                ),
                              ),

                              SizedBox(height: 3),

                              Text(
                                'Green Zone · Level 4',
                                style: TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 18,
                                  fontWeight:
                                      FontWeight.w700,
                                  color: green,
                                ),
                              ),

                              SizedBox(height: 5),

                              Text(
                                'Your screening indicates a non-critical case. '
                                'You may consider facilities with a shorter waiting time.',
                                style: TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 13,
                                  height: 1.4,
                                  color: darkTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 26),

                  const Text(
                    'Suggested care options',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Sample data is shown for the prototype.',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 12,
                      color: grey,
                    ),
                  ),

                  const SizedBox(height: 14),

                  _hospitalCard(
                    context: context,
                    badge: 'Best match',
                    hospitalName:
                        'Central General Hospital',
                    distance: '2.3 km',
                    travelTime: '8 min',
                    waitingTime: '30 min',
                    emptyBeds: '12',
                    registeredPatients: '36',
                  ),

                  const SizedBox(height: 14),

                  _hospitalCard(
                    context: context,
                    badge: 'Shortest wait',
                    hospitalName:
                        'Riverside Medical Centre',
                    distance: '5.1 km',
                    travelTime: '15 min',
                    waitingTime: '15 min',
                    emptyBeds: '8',
                    registeredPatients: '28',
                  ),

                  const SizedBox(height: 14),

                  _hospitalCard(
                    context: context,
                    badge: 'Closest',
                    hospitalName:
                        'Maple Community Hospital',
                    distance: '1.2 km',
                    travelTime: '5 min',
                    waitingTime: '45 min',
                    emptyBeds: '6',
                    registeredPatients: '42',
                  ),

                  const SizedBox(height: 18),

                  // DISCLAIMER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(16),
                      border: Border.all(
                        color: border,
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: grey,
                          size: 20,
                        ),

                        SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            'If your symptoms become severe or you develop '
                            'emergency warning signs, seek emergency care immediately.',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 12,
                              height: 1.4,
                              color: grey,
                            ),
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

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // BADGE
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),

            decoration: BoxDecoration(
              color: lightTeal,
              borderRadius:
                  BorderRadius.circular(20),
            ),

            child: Text(
              badge,
              style: const TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: darkTeal,
              ),
            ),
          ),

          const SizedBox(height: 13),

          Text(
            hospitalName,
            style: const TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: darkTeal,
            ),
          ),

          const SizedBox(height: 6),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 17,
                color: grey,
              ),

              const SizedBox(width: 4),

              Text(
                '$distance away',
                style: const TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 12,
                  color: grey,
                ),
              ),

              const SizedBox(width: 8),

              Container(
                width: 3,
                height: 3,
                decoration: const BoxDecoration(
                  color: grey,
                  shape: BoxShape.circle,
                ),
              ),

              const SizedBox(width: 8),

              Text(
                travelTime,
                style: const TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 12,
                  color: grey,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // INFORMATION
          Row(
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

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 50,

            child: ElevatedButton(
              onPressed: () {
                _showRouteOptions(
                  context,
                  hospitalName,
                );
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                foregroundColor: Colors.white,
                elevation: 0,

                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),

              child: const Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.navigation_outlined,
                    size: 19,
                  ),

                  SizedBox(width: 8),

                  Text(
                    'View Route',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
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
        Icon(
          icon,
          size: 21,
          color: darkTeal,
        ),

        const SizedBox(height: 5),

        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: darkTeal,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 10,
            color: grey,
          ),
        ),
      ],
    );
  }
}