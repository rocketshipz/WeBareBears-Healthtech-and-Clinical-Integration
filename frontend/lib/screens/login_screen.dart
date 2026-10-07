import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../theme.dart';
import 'forgot_password.dart';
import 'signup_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;

  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void login() {
    if (phoneController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      showAppSnack(
        context,
        'Please enter your phone number and password.',
      );

      return;
    }

    // Prototype login only.
    // Real authentication will be connected later.

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const MainNavigation(),
      ),
    );
  }

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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),

                    // BRAND
                    const FadeSlideIn(
                      index: 0,
                      child: Center(child: BrandWordmark()),
                    ),

                    const SizedBox(height: 28),

                    // ANIMATED ICON
                    FadeSlideIn(
                      index: 1,
                      child: Center(child: _buildPulsingHeart()),
                    ),

                    const SizedBox(height: 28),

                    // TITLE
                    FadeSlideIn(
                      index: 2,
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: AppText.display,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Log in to continue your screening.',
                              textAlign: TextAlign.center,
                              style: AppText.body,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // FORM CARD
                    FadeSlideIn(
                      index: 3,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: cardDecoration(radius: 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // PHONE NUMBER
                            fieldLabel('Phone Number'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'e.g. 0123456789',
                                icon: Icons.phone_outlined,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // PASSWORD
                            fieldLabel('Password'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passwordController,
                              obscureText: hidePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => login(),
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'Enter your password',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      hidePassword = !hidePassword;
                                    });
                                  },
                                  icon: Icon(
                                    hidePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: AppColors.grey,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 4),

                            // FORGOT PASSWORD
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(
                                  'Forgot password?',
                                  style: AppText.style(
                                    12,
                                    FontWeight.w600,
                                    AppColors.darkTeal,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            // LOGIN BUTTON
                            PrimaryButton(
                              label: 'Log in',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: login,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // SIGN UP
                    FadeSlideIn(
                      index: 4,
                      child: Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          children: [
                            Text(
                              'Don\'t have an account? ',
                              style: AppText.body,
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignUpPage(),
                                  ),
                                );
                              },
                              child: Text(
                                'Create account',
                                style: AppText.style(
                                  14,
                                  FontWeight.w700,
                                  AppColors.darkTeal,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // EMERGENCY AREA
                    FadeSlideIn(index: 5, child: _buildEmergencyCard()),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PIECES
  // ============================================================

  Widget _buildPulsingHeart() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.teal.withValues(alpha: 0.20),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: Icon(
            Icons.favorite_rounded,
            size: 42,
            color: AppColors.teal,
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.red.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.red.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_rounded,
              color: AppColors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Need immediate help?', style: AppText.caption),
                Text('Call emergency services', style: AppText.bodyStrong),
              ],
            ),
          ),
          Pressable(
            onTap: () {
              // Add phone-call function later.
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '999',
                style: AppText.style(14, FontWeight.w700, Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}