import 'package:flutter/material.dart';

import '../theme.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final emailController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool linkSent = false;
  bool linkVerified = false;

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  @override
  void dispose() {
    emailController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _sendResetLink() {
    if (emailController.text.trim().isEmpty) {
      _showMessage(
        'Please enter your email address.',
      );
      return;
    }

    setState(() {
      linkSent = true;
      linkVerified = false;
    });

    _showMessage(
      'Password reset link sent. Prototype mode.',
    );
  }

  void _verifyLink() {
    setState(() {
      linkVerified = true;
    });

    _showMessage(
      'Email link verified.',
    );
  }

  void _changePassword() {
    if (newPasswordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showMessage(
        'Please enter your new password.',
      );
      return;
    }

    if (newPasswordController.text.length < 8) {
      _showMessage(
        'Password must contain at least 8 characters.',
      );
      return;
    }

    if (newPasswordController.text != confirmPasswordController.text) {
      _showMessage(
        'Passwords do not match.',
      );
      return;
    }

    _showMessage(
      'Password changed successfully.',
    );

    Navigator.pop(context);
  }

  void _showMessage(String message) {
    showAppSnack(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final int currentStep = linkVerified ? 2 : (linkSent ? 1 : 0);

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
                          Text('Forgot your password?',
                              style: AppText.display),
                          const SizedBox(height: 8),
                          Text(
                            'Enter your registered email address and we\'ll send you a password reset link.',
                            style: AppText.body,
                          ),
                          const SizedBox(height: 20),
                          StepProgress(
                            current: currentStep,
                            labels: const [
                              'Email',
                              'Verify link',
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
                              enabled: !linkVerified,
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'name@email.com',
                                icon: Icons.mail_outline_rounded,
                              ),
                            ),

                            // SEND LINK
                            if (!linkSent) ...[
                              const SizedBox(height: 20),
                              PrimaryButton(
                                label: 'Send Reset Link',
                                icon: Icons.send_rounded,
                                onPressed: _sendResetLink,
                              ),
                            ],

                            // LINK SENT
                            if (linkSent && !linkVerified) ...[
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
                                      child: Text(
                                        'A password reset link has been sent to '
                                        '${emailController.text}.',
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
                              PrimaryButton(
                                label: 'Verify Reset Link',
                                icon: Icons.verified_outlined,
                                onPressed: _verifyLink,
                              ),
                              const SizedBox(height: 4),
                              Center(
                                child: TextButton(
                                  onPressed: _sendResetLink,
                                  child: Text(
                                    'Resend email',
                                    style: AppText.style(
                                      12,
                                      FontWeight.w600,
                                      AppColors.darkTeal,
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // RESET PASSWORD
                            if (linkVerified) ...[
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
                                      child: Text(
                                        'Email verified. You can now create a new password.',
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

                              Text(
                                'Use at least 8 characters.',
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
                                label: 'Change Password',
                                icon: Icons.check_rounded,
                                onPressed: _changePassword,
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