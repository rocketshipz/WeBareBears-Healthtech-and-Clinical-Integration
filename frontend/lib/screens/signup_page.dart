import '../localization.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final icController = TextEditingController();
  final phoneController = TextEditingController();
  final tacController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  bool tacSent = false;
  bool tacVerified = false;

  // Prototype TAC only
  final String sampleTac = '123456';

  @override
  void dispose() {
    icController.dispose();
    phoneController.dispose();
    tacController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _createAccount() {
    if (icController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showMessage(
        'Please complete all required fields.',
      );
      return;
    }

    if (passwordController.text.length < 8) {
      _showMessage(
        'Password must contain at least 8 characters.',
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showMessage(
        'Passwords do not match.',
      );
      return;
    }

    setState(() {
      tacSent = true;
      tacVerified = false;
    });

    _showMessage(
      'TAC sent to ${phoneController.text}. Prototype TAC: $sampleTac',
    );
  }

  void _verifyTac() {
    if (tacController.text.trim().isEmpty) {
      _showMessage(
        'Please enter the TAC.',
      );
      return;
    }

    if (tacController.text.trim() == sampleTac) {
      setState(() {
        tacVerified = true;
      });

      _showMessage(
        'Account created successfully!',
      );

      // Later you can navigate to another page here.
      // Example:
      //
      // Navigator.pushReplacement(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => const LoginScreen(),
      //   ),
      // );
    } else {
      setState(() {
        tacVerified = false;
      });

      _showMessage(
        'Invalid TAC. Please try again.',
      );
    }
  }

  void _resendTac() {
    setState(() {
      tacVerified = false;
      tacController.clear();
    });

    _showMessage(
      'A new TAC has been sent. Prototype TAC: $sampleTac',
    );
  }

  void _showMessage(String message) {
    showAppSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BACK + BRAND
                    FadeSlideIn(
                      index: 0,
                      child: Row(
                        children: [
                          CircleBackButton(
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                          const Expanded(
                            child: Center(child: BrandWordmark()),
                          ),
                          // Keeps the brand centred next to the back button.
                          const SizedBox(width: 42),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // TITLE
                    FadeSlideIn(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText('Create your account', style: AppText.display),
                          const SizedBox(height: 8),
                          LocalizedText(
                            'Set up your account to start using TriageMY.',
                            style: AppText.body,
                          ),
                          const SizedBox(height: 20),
                          StepProgress(
                            current: tacSent ? 1 : 0,
                            labels: const ['Your details', 'Verify phone'],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // DETAILS CARD
                    FadeSlideIn(
                      index: 2,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: cardDecoration(radius: 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // IC NUMBER
                            fieldLabel('IC Number'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: icController,
                              keyboardType: TextInputType.number,
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'e.g. 010101-01-1234',
                                icon: Icons.badge_outlined,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // PHONE NUMBER
                            fieldLabel('Phone Number'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
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
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'Create a password',
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

                            const SizedBox(height: 6),

                            LocalizedText(
                              'Use at least 8 characters.',
                              style: AppText.caption,
                            ),

                            const SizedBox(height: 18),

                            // CONFIRM PASSWORD
                            fieldLabel('Confirm Password'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: hideConfirmPassword,
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'Re-enter your password',
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  onPressed: () {
                                    setState(() {
                                      hideConfirmPassword =
                                          !hideConfirmPassword;
                                    });
                                  },
                                  icon: Icon(
                                    hideConfirmPassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: AppColors.grey,
                                  ),
                                ),
                              ),
                            ),

                            // CREATE ACCOUNT BUTTON
                            if (!tacSent) ...[
                              const SizedBox(height: 24),
                              PrimaryButton(
                                label: 'Create Account',
                                onPressed: _createAccount,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // TAC SECTION
                    if (tacSent) ...[
                      const SizedBox(height: 16),
                      FadeSlideIn(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: cardDecoration(radius: 26),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.paleTeal,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.sms_outlined,
                                      color: AppColors.darkTeal,
                                      size: 21,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: LocalizedText(
                                        'A 6-digit TAC has been sent to '
                                        '${phoneController.text}.',
                                        style: AppText.style(
                                          12,
                                          FontWeight.w500,
                                          AppColors.darkTeal,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 18),

                              fieldLabel('Enter TAC'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: tacController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                style: AppText.input,
                                decoration: appInputDecoration(
                                  hint: 'Enter 6-digit TAC',
                                  icon: Icons.password_rounded,
                                ).copyWith(
                                  counterText: '',
                                ),
                              ),

                              const SizedBox(height: 4),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _resendTac,
                                  child: LocalizedText(
                                    'Resend TAC',
                                    style: AppText.style(
                                      12,
                                      FontWeight.w600,
                                      AppColors.darkTeal,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              PrimaryButton(
                                label: tacVerified
                                    ? 'Verified'
                                    : 'Verify TAC & Create Account',
                                icon: tacVerified ? Icons.check_rounded : null,
                                color: tacVerified
                                    ? AppColors.green
                                    : AppColors.darkTeal,
                                onPressed: _verifyTac,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // LOGIN LINK
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          LocalizedText(
                            'Already have an account? ',
                            style: AppText.body,
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: LocalizedText(
                              'Log in',
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

                    const SizedBox(height: 24),

                    // INFO
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
                            Icons.verified_user_outlined,
                            size: 20,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: LocalizedText(
                              'Your phone number is verified using TAC before your account is activated.',
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
}