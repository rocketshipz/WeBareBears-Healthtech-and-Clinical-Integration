import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../theme.dart';
import 'admin_login.dart';
import 'admin_widgets.dart';
import 'admin_i18n.dart';

/// First screen of the hospital (staff) side.
class AdminLandingScreen extends StatelessWidget {
  const AdminLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),

                    // LANGUAGE
                    const FadeSlideIn(
                      index: 0,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: LanguageToggle(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // BRAND
                    const FadeSlideIn(
                      index: 0,
                      child: Column(
                        children: [
                          BrandWordmark(size: 34),
                          SizedBox(height: 8),
                          StaffTag(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // HERO ICON
                    FadeSlideIn(
                      index: 1,
                      child: Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.teal.withValues(alpha: 0.28),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_hospital_rounded,
                          size: 54,
                          color: AppColors.teal,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // TITLE
                    FadeSlideIn(
                      index: 2,
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Text(
                              tr('Hospital staff portal'),
                              textAlign: TextAlign.center,
                              style: AppText.display,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('Log each stage of a patient\'s emergency visit '
                                  'so patients and families always know what happens next.'),
                              textAlign: TextAlign.center,
                              style: AppText.body,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // FEATURES
                    FadeSlideIn(
                      index: 3,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: cardDecoration(radius: 24),
                        child: Column(
                          children: [
                            _feature(
                              Icons.format_list_bulleted_rounded,
                              tr('Live emergency queue'),
                              tr('See every patient, their zone and current stage.'),
                            ),
                            const SizedBox(height: 14),
                            _feature(
                              Icons.check_circle_outline_rounded,
                              tr('One-tap progress logging'),
                              tr('Start and complete each stage in seconds.'),
                            ),
                            const SizedBox(height: 14),
                            _feature(
                              Icons.family_restroom_rounded,
                              tr('Family updates'),
                              tr('Authorised family can follow the visit in the app.'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ACTIONS
                    FadeSlideIn(
                      index: 4,
                      child: PrimaryButton(
                        label: tr('Staff login'),
                        icon: Icons.arrow_forward_rounded,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminLoginScreen(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 14),

                    FadeSlideIn(
                      index: 5,
                      child: Pressable(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text.rich(
                            TextSpan(
                              text: tr('Not hospital staff? '),
                              style: AppText.body,
                              children: [
                                TextSpan(
                                  text: tr('Open the patient app'),
                                  style: AppText.style(
                                    14,
                                    FontWeight.w700,
                                    AppColors.darkTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _feature(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.paleTeal,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.teal, size: 21),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.bodyStrong),
              Text(subtitle, style: AppText.caption),
            ],
          ),
        ),
      ],
    );
  }
}