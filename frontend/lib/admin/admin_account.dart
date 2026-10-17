import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_landing.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';
import 'admin_i18n.dart';

class AdminAccountPage extends StatelessWidget {
  const AdminAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final staff = adminStore.staff;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FadeSlideIn(
                      index: 0,
                      child: Row(
                        children: [
                          BrandWordmark(size: 28),
                          SizedBox(width: 10),
                          StaffTag(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    FadeSlideIn(
                      index: 1,
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        AppColors.teal.withValues(alpha: 0.20),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.badge_rounded,
                                size: 42,
                                color: AppColors.darkTeal,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              staff?.name ?? tr('Staff'),
                              style: AppText.display,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${tr(staff?.role ?? '')} · ${staff?.id ?? ''}',
                              style: AppText.bodyStrong,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              staff?.hospital ?? '',
                              style: AppText.body,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    FadeSlideIn(
                      index: 2,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        decoration: cardDecoration(radius: 24),
                        child: Column(
                          children: [
                            _row(tr('Name'), staff?.name ?? '-'),
                            const Divider(height: 1, color: AppColors.border),
                            _row(tr('Staff ID'), staff?.id ?? '-'),
                            const Divider(height: 1, color: AppColors.border),
                            _row(tr('Role'), tr(staff?.role ?? '-')),
                            const Divider(height: 1, color: AppColors.border),
                            _row(tr('Hospital'), staff?.hospital ?? '-'),
                            const Divider(height: 1, color: AppColors.border),
                            _row(tr('Department'), tr(staff?.department ?? '-')),
                            const Divider(height: 1, color: AppColors.border),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      tr('Language'),
                                      style: AppText.caption,
                                    ),
                                  ),
                                  const LanguageToggle(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    FadeSlideIn(
                      index: 3,
                      child: Container(
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
                              size: 20,
                              color: AppColors.teal,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                adminStore.repo.isDemo
                                    ? tr('Demo mode: sample data only. Nothing is saved '
                                        'and everything resets when the app restarts.')
                                    : tr('Connected to Supabase. Every update you make is '
                                        'saved with your name and staff ID.'),
                                style: AppText.caption,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    FadeSlideIn(
                      index: 4,
                      child: PrimaryButton(
                        label: tr('Log out'),
                        icon: Icons.logout_rounded,
                        color: AppColors.red,
                        onPressed: () async {
                          await adminStore.signOut();

                          if (!context.mounted) return;

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminLandingScreen(),
                            ),
                            (route) => false,
                          );
                        },
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

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(label, style: AppText.caption)),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }
}