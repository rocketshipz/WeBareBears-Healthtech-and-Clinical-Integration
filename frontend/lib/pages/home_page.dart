import 'package:flutter/material.dart';
import 'triage_engine.dart';
import 'hospital_homepage.dart';
import 'profile_page.dart';
import 'notifications_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int currentIndex = 0;

  static const Color teal = Color(0xFF3BB8C1);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color background = Color(0xFFF7FBFB);

  late final List<Widget> pages;

  @override
void initState() {
  super.initState();

  pages = [
    HomePage(
      onStartTriage: () {
        setState(() {
          currentIndex = 1;
        });
      },

      onHospitals: () {
        setState(() {
          currentIndex = 2;
        });
      },

      onMedicalHistory: () {
        setState(() {
          currentIndex = 3;
        });
      },
    ),

    const TriagePage(),
    const HospitalsPage(),
    const ProfilePage(),
  ];
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: pages[currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,

        selectedItemColor: teal,
        unselectedItemColor: grey,

        backgroundColor: Colors.white,
        elevation: 8,

        selectedLabelStyle: const TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),

        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 12,
        ),

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Triage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_hospital_outlined),
            activeIcon: Icon(Icons.local_hospital_rounded),
            label: 'Hospitals',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
final VoidCallback onStartTriage;
final VoidCallback onMedicalHistory;
final VoidCallback onHospitals;

const HomePage({
  super.key,
  required this.onStartTriage,
  required this.onMedicalHistory,
  required this.onHospitals,
});

  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color background = Color(0xFFF7FBFB);
  static const Color lightTeal = Color(0xFFE4F7F6);
  static const Color cardBorder = Color(0xFFE4ECEC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BRAND
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 24,
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

                      InkWell(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationsPage(),
      ),
    );
  },
  borderRadius: BorderRadius.circular(30),

  child: Container(
    width: 42,
    height: 42,
    decoration: const BoxDecoration(
      color: lightTeal,
      shape: BoxShape.circle,
    ),
    child: const Icon(
      Icons.notifications_none_rounded,
      color: darkTeal,
      size: 22,
    ),
  ),
),
                    ],
                  ),

                  const SizedBox(height: 38),

                  // GREETING
                  const Text(
                    'Good morning',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'How can we help you today?',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 15,
                      color: grey,
                    ),
                  ),
                  // MEDICAL PROFILE REMINDER
Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: lightTeal,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: const Color(0xFFD5ECEB),
    ),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.medical_information_outlined,
          color: darkTeal,
          size: 21,
        ),
      ),

      const SizedBox(width: 12),

      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Complete your medical profile',
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: darkTeal,
              ),
            ),

            SizedBox(height: 4),

            Text(
              'Add your allergies, medications and medical history to support your triage screening.',
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 12,
                height: 1.4,
                color: grey,
              ),
            ),
          ],
        ),
      ),

      const SizedBox(width: 8),

      TextButton(
        onPressed: onMedicalHistory,
        child: const Text(
          'Complete',
          style: TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: teal,
          ),
        ),
      ),
    ],
  ),
),

                  const SizedBox(height: 28),
                  

                  // MAIN TRIAGE CARD
                  InkWell(
                    onTap: onStartTriage,
                    borderRadius: BorderRadius.circular(20),

                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),

                      decoration: BoxDecoration(
                        color: teal,
                        borderRadius: BorderRadius.circular(20),
                      ),

                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.health_and_safety_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),

                          const SizedBox(width: 16),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Triage',
                                  style: TextStyle(
                                    fontFamily: 'Helvetica',
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),

                                SizedBox(height: 5),

                                Text(
                                  'Answer a few questions about your symptoms.',
                                  style: TextStyle(
                                    fontFamily: 'Helvetica',
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // SECONDARY CARDS
                  Row(
                    children: [
                      Expanded(
                        child: _smallCard(
                          icon: Icons.medical_information_outlined,
                          title: 'Medical History',
                          subtitle: 'View your health information',
                          onTap: onMedicalHistory,
                          ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _smallCard(
                              icon: Icons.local_hospital_outlined,
                              title: 'Hospitals & Clinics',
                              subtitle: 'Find care near you',
                              onTap: onHospitals,
                              ),
                              ),
                              ],
                              ),

                  // RECENT ACTIVITY
                  const Text(
                    'Recent activity',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),

                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: cardBorder,
                      ),
                    ),

                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            color: lightTeal,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_turned_in_outlined,
                            color: darkTeal,
                            size: 22,
                          ),
                        ),

                        const SizedBox(width: 14),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No recent triage',
                                style: TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: darkTeal,
                                ),
                              ),

                              SizedBox(height: 3),

                              Text(
                                'Your latest screening result will appear here.',
                                style: TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 12,
                                  height: 1.4,
                                  color: grey,
                                ),
                              ),
                            ],
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

  Widget _smallCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),

      child: Container(
        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: cardBorder,
          ),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,

              decoration: const BoxDecoration(
                color: lightTeal,
                shape: BoxShape.circle,
              ),

              child: Icon(
                icon,
                color: darkTeal,
                size: 21,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: darkTeal,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              subtitle,
              style: const TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 12,
                height: 1.4,
                color: grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Helvetica',
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0D5C63),
        ),
      ),
    );
  }
}