import 'package:flutter/material.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color background = Color(0xFFF7FBFB);
  static const Color lightTeal = Color(0xFFE4F7F6);
  static const Color fieldBackground = Color(0xFFF3F7F7);

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

    if (passwordController.text !=
        confirmPasswordController.text) {
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
            10,
            24,
            32,
          ),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 430,
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BRAND
                  Center(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(
                            text: 'Triage',
                            style: TextStyle(
                              color: darkTeal,
                            ),
                          ),
                          TextSpan(
                            text: 'MY',
                            style: TextStyle(
                              color: teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // TITLE
                  const Text(
                    'Create your account',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'Set up your account to start using TriageMY.',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 14,
                      height: 1.4,
                      color: grey,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // IC NUMBER
                  _label('IC Number'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: icController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      hint: 'e.g. 010101-01-1234',
                      icon: Icons.badge_outlined,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // PHONE NUMBER
                  _label('Phone Number'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      hint: 'e.g. 0123456789',
                      icon: Icons.phone_outlined,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // PASSWORD
                  _label('Password'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: passwordController,
                    obscureText: hidePassword,

                    decoration: _inputDecoration(
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
                          color: grey,
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

                  // CONFIRM PASSWORD
                  _label('Confirm Password'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: confirmPasswordController,
                    obscureText: hideConfirmPassword,

                    decoration: _inputDecoration(
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
                          color: grey,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // CREATE ACCOUNT BUTTON
                  if (!tacSent)
                    SizedBox(
                      width: double.infinity,
                      height: 58,

                      child: ElevatedButton(
                        onPressed: _createAccount,

                        style: ElevatedButton.styleFrom(
                          backgroundColor: teal,
                          foregroundColor: Colors.white,
                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),

                        child: const Text(
                          'Create Account',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                  // TAC SECTION
                  if (tacSent) ...[
                    Container(
                      width: double.infinity,

                      padding: const EdgeInsets.all(16),

                      decoration: BoxDecoration(
                        color: lightTeal,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sms_outlined,
                            color: darkTeal,
                            size: 21,
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              'A 6-digit TAC has been sent to '
                              '${phoneController.text}.',
                              style: const TextStyle(
                                fontFamily: 'Helvetica',
                                fontSize: 12,
                                height: 1.4,
                                color: darkTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _label('Enter TAC'),

                    const SizedBox(height: 8),

                    TextField(
                      controller: tacController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,

                      decoration: _inputDecoration(
                        hint: 'Enter 6-digit TAC',
                        icon: Icons.password_rounded,
                      ).copyWith(
                        counterText: '',
                      ),
                    ),

                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,

                      child: TextButton(
                        onPressed: _resendTac,

                        child: const Text(
                          'Resend TAC',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: darkTeal,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 58,

                      child: ElevatedButton(
                        onPressed: _verifyTac,

                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              tacVerified ? const Color(0xFF2E9E70) : teal,
                          foregroundColor: Colors.white,
                          elevation: 0,

                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),

                        child: Text(
                          tacVerified
                              ? 'Verified'
                              : 'Verify TAC & Create Account',
                          style: const TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
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
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 13,
                            color: grey,
                          ),
                        ),

                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },

                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: darkTeal,
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

                    padding: const EdgeInsets.all(15),

                    decoration: BoxDecoration(
                      color: lightTeal,
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          size: 19,
                          color: darkTeal,
                        ),

                        SizedBox(width: 9),

                        Expanded(
                          child: Text(
                            'Your phone number is verified using TAC before your account is activated.',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 11,
                              height: 1.4,
                              color: darkTeal,
                            ),
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

      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 19,
      ),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: teal,
          width: 1.5,
        ),
      ),
    );
  }
}