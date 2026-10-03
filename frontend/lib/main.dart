import 'package:flutter/material.dart';

void main() {
  runApp(const TriageMYApp());
}

class TriageMYApp extends StatelessWidget {
  const TriageMYApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TriageMY',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Helvetica',
        scaffoldBackgroundColor: const Color(0xFFF7FBFB),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // Brand colours
  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color red = Color(0xFFED254E);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color fieldBackground = Color(0xFFF3F7F7);

  final emailController = TextEditingController();
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
    emailController.dispose();
    passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void login() {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email and password.'),
        ),
      );
      return;
    }

    // Add login authentication later.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBFB),
      body: SafeArea(
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
                  Center(
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                        children: [
                          TextSpan(
                            text: 'Triage',
                            style: TextStyle(color: darkTeal),
                          ),
                          TextSpan(
                            text: 'MY',
                            style: TextStyle(color: teal),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // SIMPLE ANIMATED HEALTH ICON
                  Center(
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4F7F6),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: teal.withValues(alpha: 0.10),
                              blurRadius: 35,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.favorite_rounded,
                            size: 42,
                            color: teal,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 38),

                  // TITLE
                  const Text(
                    'Welcome back',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Log in to continue your screening.',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 15,
                      height: 1.4,
                      color: grey,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // EMAIL
                  _buildLabel('Email'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration(
                      hint: 'name@email.com',
                      icon: Icons.mail_outline_rounded,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // PASSWORD
                  _buildLabel('Password'),

                  const SizedBox(height: 8),

                  TextField(
                    controller: passwordController,
                    obscureText: hidePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => login(),
                    decoration: _inputDecoration(
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
                          size: 21,
                          color: grey,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 13,
                          color: darkTeal,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // LOGIN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: teal,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Log in',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // CREATE ACCOUNT
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        const Text(
                          'Don\'t have an account? ',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 14,
                            color: grey,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            // Add sign-up page later.
                          },
                          child: const Text(
                            'Create account',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 14,
                              color: darkTeal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 42),

                  // EMERGENCY AREA
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: red.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phone_rounded,
                            color: red,
                            size: 19,
                          ),
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Need immediate help?',
                                style: TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 13,
                                  color: grey,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Call emergency services',
                                style: TextStyle(
                                  fontFamily: 'Helvetica',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: darkTeal,
                                ),
                              ),
                            ],
                          ),
                        ),

                        TextButton(
                          onPressed: () {
                            // Add call functionality later.
                          },
                          child: const Text(
                            '999',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
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