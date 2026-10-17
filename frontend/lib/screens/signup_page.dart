import '../localization.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';
import 'login_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final icController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  bool codeSent = false;
  bool codeVerified = false;
  bool isSendingCode = false;
  bool isRegistering = false;

  @override
  void dispose() {
    icController.dispose();
    phoneController.dispose();
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r"^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$").hasMatch(email.trim());
  }

  Future<void> _sendVerificationCode() async {
    if (isSendingCode) return;

    final ic = icController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (ic.isEmpty || phone.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please complete all required fields.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (password.length < 8) {
      _showMessage('Password must contain at least 8 characters.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() {
      isSendingCode = true;
    });

    try {
      final response = await AuthService.sendVerificationCode(email: email);
      if (!mounted) return;

      setState(() {
        codeSent = true;
        codeVerified = false;
      });

      final message = response['message'] ?? 'Verification code sent to $email.';
      _showMessage(message);
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Failed to send code: $e');
    } finally {
      if (mounted) {
        setState(() {
          isSendingCode = false;
        });
      }
    }
  }

  Future<void> _verifyAndRegister() async {
    if (isRegistering) return;

    final code = codeController.text.trim();
    final email = emailController.text.trim();
    final ic = icController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text;

    if (code.isEmpty || code.length != 6) {
      _showMessage('Please enter the 6-digit verification code.');
      return;
    }

    setState(() {
      isRegistering = true;
    });

    try {
      // Step 1: Verify 6-digit code
      await AuthService.verifyCode(email: email, code: code);

      // Step 2: Register account
      await AuthService.register(
        ic: ic,
        phone: phone,
        email: email,
        password: password,
        code: code,
      );

      if (!mounted) return;
      setState(() {
        codeVerified = true;
      });

      _showMessage('Account created successfully!');

      // Navigate to login screen
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Registration error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isRegistering = false;
        });
      }
    }
  }

  Future<void> _resendCode() async {
    final email = emailController.text.trim();
    if (email.isEmpty) return;

    try {
      await AuthService.sendVerificationCode(email: email);
      if (!mounted) return;
      _showMessage('A new 6-digit verification code has been sent to $email.');
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    }
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
                            current: codeSent ? 1 : 0,
                            labels: const ['Your details', 'Verify email'],
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
                              keyboardType: TextInputType.text,
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

                            // EMAIL ADDRESS
                            fieldLabel('Email Address'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'e.g. user@example.com',
                                icon: Icons.email_outlined,
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

                            // SEND CODE BUTTON
                            if (!codeSent) ...[
                              const SizedBox(height: 24),
                              PrimaryButton(
                                label: isSendingCode
                                    ? 'Sending code...'
                                    : 'Send Verification Code',
                                icon: isSendingCode
                                    ? null
                                    : Icons.arrow_forward_rounded,
                                onPressed: isSendingCode
                                    ? null
                                    : _sendVerificationCode,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // EMAIL VERIFICATION CODE SECTION
                    if (codeSent) ...[
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
                                      Icons.mark_email_read_outlined,
                                      color: AppColors.darkTeal,
                                      size: 21,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'A 6-digit verification code has been sent to '
                                        '${emailController.text}. Please check your inbox.',
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

                              fieldLabel('Enter 6-Digit Code'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: codeController,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                style: AppText.input,
                                decoration: appInputDecoration(
                                  hint: 'Enter 6-digit code',
                                  icon: Icons.password_rounded,
                                ).copyWith(
                                  counterText: '',
                                ),
                              ),

                              const SizedBox(height: 4),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _resendCode,
                                  child: Text(
                                    'Resend Code',
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
                                label: isRegistering
                                    ? 'Verifying & Creating...'
                                    : codeVerified
                                        ? 'Verified'
                                        : 'Verify & Create Account',
                                icon: codeVerified ? Icons.check_rounded : null,
                                color: codeVerified
                                    ? AppColors.green
                                    : AppColors.darkTeal,
                                onPressed: (isRegistering || codeVerified)
                                    ? null
                                    : _verifyAndRegister,
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
                            child: Text(
                              'A 6-digit verification code is sent to your email to verify your identity before account activation.',
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