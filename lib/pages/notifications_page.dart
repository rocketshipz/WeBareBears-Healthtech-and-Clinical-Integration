import 'package:flutter/material.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color background = Color(0xFFF7FBFB);
  static const Color lightTeal = Color(0xFFE4F7F6);
  static const Color border = Color(0xFFE3ECEC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkTeal,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'Notifications',
          style: TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: darkTeal,
          ),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            18,
            20,
            30,
          ),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 600,
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent updates',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 14),

                  _notificationCard(
                    icon: Icons.assignment_turned_in_outlined,
                    title: 'Triage result ready',
                    message:
                        'Your latest triage screening has been completed.',
                    time: 'Just now',
                    unread: true,
                  ),

                  const SizedBox(height: 12),

                  _notificationCard(
                    icon: Icons.local_hospital_outlined,
                    title: 'Hospital wait time updated',
                    message:
                        'A nearby hospital now has a shorter estimated waiting time.',
                    time: '10 min ago',
                    unread: true,
                  ),

                  const SizedBox(height: 12),

                  _notificationCard(
                    icon: Icons.medical_information_outlined,
                    title: 'Review your medical history',
                    message:
                        'Keep your allergies, medications, and medical conditions up to date.',
                    time: 'Yesterday',
                    unread: false,
                  ),

                  const SizedBox(height: 12),

                  _notificationCard(
                    icon: Icons.contact_phone_outlined,
                    title: 'Emergency contact reminder',
                    message:
                        'Make sure your emergency contact information is correct.',
                    time: '2 days ago',
                    unread: false,
                  ),

                  const SizedBox(height: 12),

                  _notificationCard(
                    icon: Icons.info_outline_rounded,
                    title: 'Welcome to TriageMY',
                    message:
                        'Use TriageMY to screen symptoms and explore suitable care options.',
                    time: '3 days ago',
                    unread: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationCard({
    required IconData icon,
    required String title,
    required String message,
    required String time,
    required bool unread,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: unread
            ? lightTeal.withValues(alpha: 0.55)
            : Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: unread ? teal.withValues(alpha: 0.25) : border,
        ),
      ),

      child: Row(
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

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 14,
                          fontWeight: unread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: darkTeal,
                        ),
                      ),
                    ),

                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(
                          top: 4,
                          left: 8,
                        ),
                        decoration: const BoxDecoration(
                          color: teal,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 12,
                    height: 1.4,
                    color: grey,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  time,
                  style: const TextStyle(
                    fontFamily: 'Helvetica',
                    fontSize: 11,
                    color: Color(0xFFA5B2B2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}