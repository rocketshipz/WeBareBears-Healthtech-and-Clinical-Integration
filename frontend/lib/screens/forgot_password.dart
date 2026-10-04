import 'package:flutter/material.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState
    extends State<ForgotPasswordPage> {
  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color background = Color(0xFFF7FBFB);
  static const Color lightTeal = Color(0xFFE4F7F6);
  static const Color fieldBackground = Color(0xFFF3F7F7);

  final emailController = TextEditingController();
  final newPasswordController =
      TextEditingController();
  final confirmPasswordController =
      TextEditingController();

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

    if (newPasswordController.text !=
        confirmPasswordController.text) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

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
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            15,
            24,
            32,
          ),

          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(
                maxWidth: 430,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  const Center(
                    child: CircleAvatar(
                      radius: 44,
                      backgroundColor:
                          lightTeal,

                      child: Icon(
                        Icons.lock_reset_rounded,
                        size: 40,
                        color: teal,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  const Text(
                    'Forgot your password?',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 28,
                      fontWeight:
                          FontWeight.w700,
                      letterSpacing: -0.6,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Enter your registered email address and we\'ll send you a password reset link.',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 14,
                      height: 1.4,
                      color: grey,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // EMAIL
                  _label('Email Address'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: emailController,
                    keyboardType:
                        TextInputType.emailAddress,

                    enabled: !linkVerified,

                    decoration:
                        _inputDecoration(
                      hint: 'name@email.com',
                      icon:
                          Icons.mail_outline_rounded,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // SEND LINK
                  if (!linkSent)
                    SizedBox(
                      width: double.infinity,
                      height: 58,

                      child: ElevatedButton(
                        onPressed: _sendResetLink,

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor: teal,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),

                        child: const Text(
                          'Send Reset Link',
                          style: TextStyle(
                            fontFamily:
                                'Helvetica',
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // LINK SENT
                  if (linkSent &&
                      !linkVerified) ...[
                    Container(
                      width: double.infinity,

                      padding:
                          const EdgeInsets.all(
                        16,
                      ),

                      decoration:
                          BoxDecoration(
                        color: lightTeal,
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),

                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [
                          const Icon(
                            Icons
                                .mark_email_read_outlined,
                            color: darkTeal,
                            size: 21,
                          ),

                          const SizedBox(
                              width: 10),

                          Expanded(
                            child: Text(
                              'A password reset link has been sent to '
                              '${emailController.text}.',

                              style:
                                  const TextStyle(
                                fontFamily:
                                    'Helvetica',
                                fontSize: 12,
                                height: 1.4,
                                color: darkTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 56,

                      child: ElevatedButton(
                        onPressed: _verifyLink,

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              darkTeal,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),

                        child: const Text(
                          'Verify Reset Link',
                          style: TextStyle(
                            fontFamily:
                                'Helvetica',
                            fontSize: 14,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Center(
                      child: TextButton(
                        onPressed:
                            _sendResetLink,

                        child: const Text(
                          'Resend email',
                          style: TextStyle(
                            fontFamily:
                                'Helvetica',
                            fontSize: 12,
                            color: darkTeal,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // RESET PASSWORD
                  if (linkVerified) ...[
                    Container(
                      width: double.infinity,

                      padding:
                          const EdgeInsets.all(
                        15,
                      ),

                      decoration:
                          BoxDecoration(
                        color: lightTeal,
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),

                      child: const Row(
                        children: [
                          Icon(
                            Icons
                                .verified_rounded,
                            color: teal,
                            size: 21,
                          ),

                          SizedBox(width: 9),

                          Expanded(
                            child: Text(
                              'Email verified. You can now create a new password.',
                              style: TextStyle(
                                fontFamily:
                                    'Helvetica',
                                fontSize: 12,
                                color: darkTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    _label('New Password'),

                    const SizedBox(height: 8),

                    TextField(
                      controller:
                          newPasswordController,
                      obscureText: hidePassword,

                      decoration:
                          _inputDecoration(
                        hint:
                            'Enter new password',
                        icon: Icons
                            .lock_outline_rounded,

                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              hidePassword =
                                  !hidePassword;
                            });
                          },

                          icon: Icon(
                            hidePassword
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                            color: grey,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 7),

                    const Text(
                      'Use at least 8 characters.',
                      style: TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 11,
                        color: grey,
                      ),
                    ),

                    const SizedBox(height: 20),

                    _label(
                      'Confirm New Password',
                    ),

                    const SizedBox(height: 8),

                    TextField(
                      controller:
                          confirmPasswordController,
                      obscureText:
                          hideConfirmPassword,

                      decoration:
                          _inputDecoration(
                        hint:
                            'Re-enter new password',
                        icon: Icons
                            .lock_outline_rounded,

                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              hideConfirmPassword =
                                  !hideConfirmPassword;
                            });
                          },

                          icon: Icon(
                            hideConfirmPassword
                                ? Icons
                                    .visibility_off_outlined
                                : Icons
                                    .visibility_outlined,
                            color: grey,
                            size: 20,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      height: 58,

                      child: ElevatedButton(
                        onPressed:
                            _changePassword,

                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor: teal,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,

                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                          ),
                        ),

                        child: const Text(
                          'Change Password',
                          style: TextStyle(
                            fontFamily:
                                'Helvetica',
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,

      style: const TextStyle(
        fontFamily: 'Helvetica',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: darkTeal,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,

      hintStyle: const TextStyle(
        fontFamily: 'Helvetica',
        fontSize: 14,
        color: Color(0xFFA5B2B2),
      ),

      prefixIcon: Icon(
        icon,
        size: 21,
        color: grey,
      ),

      suffixIcon: suffix,

      filled: true,
      fillColor: fieldBackground,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 19,
      ),

      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),

        borderSide: const BorderSide(
          color: teal,
          width: 1.5,
        ),
      ),
    );
  }
}