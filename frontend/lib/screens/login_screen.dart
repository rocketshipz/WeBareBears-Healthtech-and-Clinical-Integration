import '../localization.dart';
import 'package:flutter/material.dart';

import '../pages/home_page.dart';
import '../theme.dart';
import 'forgot_password.dart';
import 'signup_page.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final identifierController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

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
    identifierController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (isLoading) return;

    final identifier = identifierController.text.trim();
    final password = passwordController.text;

    if (identifier.isEmpty || password.isEmpty) {
      showAppSnack(
        context,
        'Please enter your email, phone, or IC and password.',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await AuthService.login(
        identifier: identifier,
        password: password,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const MainNavigation(),
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.message);
    } catch (e) {
      if (!mounted) return;
      showAppSnack(context, 'Login error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      appBar: Navigator.of(context).canPop()
          ? buildAppBar('Choose account type')
          : null,
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
                            LocalizedText(
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: AppText.display,
                            ),
                            const SizedBox(height: 8),
                            LocalizedText(
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
                            // EMAIL / PHONE / IC
                            fieldLabel('Email, Phone Number, or IC'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: identifierController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'e.g. user@example.com or 0123456789',
                                icon: Icons.person_outline_rounded,
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
                                child: LocalizedText(
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
                              label: isLoading ? 'Logging in...' : 'Log in',
                              icon: isLoading ? null : Icons.arrow_forward_rounded,
                              onPressed: isLoading ? null : login,
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
                            LocalizedText(
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
                              child: LocalizedText(
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
                LocalizedText('Need immediate help?', style: AppText.caption),
                LocalizedText('Call emergency services', style: AppText.bodyStrong),
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
              child: LocalizedText(
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
