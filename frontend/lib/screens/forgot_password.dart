import '../localization.dart';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool codeSent = false;
  bool codeVerified = false;
  bool isBusy = false;

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String password) =>
      password.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(password) &&
      RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[0-9]').hasMatch(password) &&
      RegExp(r'[^a-zA-Z0-9\s]').hasMatch(password);

  /// Runs an API call with the busy flag set, showing any error as a snack.
  Future<void> _run(Future<void> Function() action) async {
    if (isBusy) return;
    setState(() => isBusy = true);
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) _showMessage(e.message);
    } finally {
      if (mounted) setState(() => isBusy = false);
    }
  }

  Future<void> _sendResetCode() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Please enter your email address.');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    await _run(() async {
      final response = await AuthService.requestPasswordReset(email: email);
      if (!mounted) return;
      setState(() {
        codeSent = true;
        codeVerified = false;
        codeController.clear();
      });
      _showMessage(response['message'] ?? 'Reset code sent.');
    });
  }

  Future<void> _verifyCode() async {
    final code = codeController.text.trim();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _showMessage('Please enter the 6-digit verification code.');
      return;
    }

    await _run(() async {
      await AuthService.verifyResetCode(
        email: emailController.text,
        code: code,
      );
      if (!mounted) return;
      setState(() => codeVerified = true);
    });
  }

  Future<void> _changePassword() async {
    final password = newPasswordController.text;
    if (password.isEmpty || confirmPasswordController.text.isEmpty) {
      _showMessage('Please enter your new password.');
      return;
    }

    if (!_isStrongPassword(password)) {
      _showMessage(
        'Password needs at least 8 characters, uppercase, lowercase, a number and a symbol.',
      );
      return;
    }

    if (password != confirmPasswordController.text) {
      _showMessage('Passwords do not match.');
      return;
    }

    await _run(() async {
      await AuthService.resetPassword(
        email: emailController.text,
        code: codeController.text,
        newPassword: password,
      );
      if (!mounted) return;
      _showMessage('Password changed successfully.');
      Navigator.pop(context);
    });
  }

  void _showMessage(String message) {
    showAppSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final int currentStep = codeVerified ? 2 : (codeSent ? 1 : 0);

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
                    // BACK
                    FadeSlideIn(
                      index: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CircleBackButton(
                          onTap: () {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ICON
                    FadeSlideIn(
                      index: 1,
                      child: Center(
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
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 42,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // TITLE
                    FadeSlideIn(
                      index: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            'Forgot your password?',
                            style: AppText.display,
                          ),
                          const SizedBox(height: 8),
                          LocalizedText(
                            'Enter your registered email address and we\'ll send you a 6-digit code to reset your password.',
                            style: AppText.body,
                          ),
                          const SizedBox(height: 20),
                          StepProgress(
                            current: currentStep,
                            labels: const [
                              'Email',
                              'Verify code',
                              'New password',
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // MAIN CARD
                    FadeSlideIn(
                      index: 3,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: cardDecoration(radius: 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // EMAIL
                            fieldLabel('Email Address'),
                            const SizedBox(height: 8),
                            TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              enabled: !codeSent,
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'name@email.com',
                                icon: Icons.mail_outline_rounded,
                              ),
                            ),

                            // SEND CODE
                            if (!codeSent) ...[
                              const SizedBox(height: 20),
                              PrimaryButton(
                                label: isBusy
                                    ? 'Sending code...'
                                    : 'Send Reset Code',
                                icon: Icons.send_rounded,
                                onPressed: isBusy ? null : _sendResetCode,
                              ),
                            ],

                            // CODE SENT
                            if (codeSent && !codeVerified) ...[
                              const SizedBox(height: 20),
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
                                      child: LocalizedText(
                                        'If an account is registered to '
                                        '${emailController.text.trim()}, a 6-digit reset code has been sent to it.',
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
                                ).copyWith(counterText: ''),
                              ),
                              const SizedBox(height: 18),
                              PrimaryButton(
                                label: isBusy ? 'Verifying...' : 'Verify Code',
                                icon: Icons.verified_outlined,
                                onPressed: isBusy ? null : _verifyCode,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    onPressed: isBusy
                                        ? null
                                        : () => setState(() {
                                            codeSent = false;
                                            codeController.clear();
                                          }),
                                    child: LocalizedText(
                                      'Change email',
                                      style: AppText.style(
                                        12,
                                        FontWeight.w600,
                                        AppColors.darkTeal,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: isBusy ? null : _sendResetCode,
                                    child: LocalizedText(
                                      'Resend Code',
                                      style: AppText.style(
                                        12,
                                        FontWeight.w600,
                                        AppColors.darkTeal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // RESET PASSWORD
                            if (codeVerified) ...[
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.paleTeal,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.verified_rounded,
                                      color: AppColors.teal,
                                      size: 21,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: LocalizedText(
                                        'Code verified. You can now create a new password.',
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

                              const SizedBox(height: 22),

                              fieldLabel('New Password'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: newPasswordController,
                                obscureText: hidePassword,
                                style: AppText.input,
                                decoration: appInputDecoration(
                                  hint: 'Enter new password',
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
                                      color: AppColors.grey,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 6),

                              LocalizedText(
                                'Use 8+ characters with uppercase, lowercase, a number and a symbol.',
                                style: AppText.caption,
                              ),

                              const SizedBox(height: 18),

                              fieldLabel('Confirm New Password'),
                              const SizedBox(height: 8),
                              TextField(
                                controller: confirmPasswordController,
                                obscureText: hideConfirmPassword,
                                style: AppText.input,
                                decoration: appInputDecoration(
                                  hint: 'Re-enter new password',
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
                                      color: AppColors.grey,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),

                              PrimaryButton(
                                label: isBusy
                                    ? 'Changing password...'
                                    : 'Change Password',
                                icon: Icons.check_rounded,
                                onPressed: isBusy ? null : _changePassword,
                              ),
                            ],
                          ],
                        ),
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
