import 'package:flutter/material.dart';

import '../theme.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                          Text('Notifications', style: AppText.heading),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    FadeSlideIn(
                      index: 1,
                      child: Text('Recent updates', style: AppText.display),
                    ),

                    const SizedBox(height: 20),

                    FadeSlideIn(
                      index: 2,
                      child: _notificationCard(
                        icon: Icons.assignment_turned_in_outlined,
                        title: 'Triage result ready',
                        message:
                            'Your latest triage screening has been completed.',
                        time: 'Just now',
                        unread: true,
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeSlideIn(
                      index: 3,
                      child: _notificationCard(
                        icon: Icons.local_hospital_outlined,
                        title: 'Hospital wait time updated',
                        message:
                            'A nearby hospital now has a shorter estimated waiting time.',
                        time: '10 min ago',
                        unread: true,
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeSlideIn(
                      index: 4,
                      child: _notificationCard(
                        icon: Icons.medical_information_outlined,
                        title: 'Review your medical history',
                        message:
                            'Keep your allergies, medications, and medical conditions up to date.',
                        time: 'Yesterday',
                        unread: false,
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeSlideIn(
                      index: 5,
                      child: _notificationCard(
                        icon: Icons.contact_phone_outlined,
                        title: 'Emergency contact reminder',
                        message:
                            'Make sure your emergency contact information is correct.',
                        time: '2 days ago',
                        unread: false,
                      ),
                    ),

                    const SizedBox(height: 12),

                    FadeSlideIn(
                      index: 6,
                      child: _notificationCard(
                        icon: Icons.info_outline_rounded,
                        title: 'Welcome to TriageMY',
                        message:
                            'Use TriageMY to screen symptoms and explore suitable care options.',
                        time: '3 days ago',
                        unread: false,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: unread
            ? Border.all(color: AppColors.teal.withValues(alpha: 0.35))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: unread ? AppColors.darkTeal : AppColors.paleTeal,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: unread ? Colors.white : AppColors.darkTeal,
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
                        style: unread
                            ? AppText.bodyStrong
                            : AppText.style(
                                14,
                                FontWeight.w600,
                                AppColors.textDark,
                              ),
                      ),
                    ),
                    if (unread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6, left: 8),
                        decoration: const BoxDecoration(
                          color: AppColors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(message, style: AppText.body),
                const SizedBox(height: 8),
                Text(time, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}