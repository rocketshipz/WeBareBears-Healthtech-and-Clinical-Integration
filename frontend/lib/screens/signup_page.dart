import '../localization.dart';
import '../countries.dart';

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
  final nameController = TextEditingController();
  String? selectedSex;
  String? selectedNationality;
  DateTime? selectedBirthDate;
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
  void initState() {
    super.initState();
    for (final controller in [
      emailController,
      phoneController,
      passwordController,
      confirmPasswordController,
    ]) {
      controller.addListener(_refreshValidation);
    }
  }

  void _refreshValidation() => setState(() {});

  bool get _credentialsValid =>
      _isValidEmail(emailController.text) &&
      _isValidPhone(phoneController.text) &&
      _isStrongPassword(passwordController.text) &&
      passwordController.text == confirmPasswordController.text;

  InputDecoration _validatedDecoration({
    required String hint,
    required IconData icon,
    required String value,
    required bool valid,
    required String invalidMessage,
    String? validMessage,
    Widget? suffix,
  }) {
    final base = appInputDecoration(hint: hint, icon: icon, suffix: suffix);
    if (value.isEmpty) return base;
    final color = valid ? AppColors.green : AppColors.red;
    final border = base.enabledBorder!.copyWith(
      borderSide: BorderSide(color: color, width: 1.5),
    );
    return base.copyWith(
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
      errorBorder: border,
      focusedErrorBorder: border,
      errorText: valid ? null : tr(invalidMessage),
      errorMaxLines: 2,
      helperText: valid && validMessage != null ? tr(validMessage) : null,
      helperStyle: AppText.caption.copyWith(color: AppColors.green),
      suffixIcon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            valid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: color,
            semanticLabel: valid ? 'Requirements met' : 'Check this field',
          ),
          if (suffix != null) suffix else const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _passwordCriterion(String label, bool met) {
    final color = met
        ? AppColors.green
        : (passwordController.text.isEmpty ? AppColors.grey : AppColors.red);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(label),
              style: AppText.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    icController.dispose();
    phoneController.dispose();
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final clean = email.trim();
    final local = clean.split('@').first;
    return clean.length <= 254 &&
        local.length <= 64 &&
        !local.startsWith('.') &&
        !local.endsWith('.') &&
        !local.contains('..') &&
        RegExp(
          r"^[a-zA-Z0-9!#$%&'*+/=?^_`{|}~.-]+@(?:[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$",
        ).hasMatch(clean);
  }

  bool _isValidPhone(String phone) {
    var clean = phone.replaceAll(RegExp(r'[ ()-]'), '');
    if (clean.startsWith('01')) clean = '+6$clean';
    if (clean.startsWith('60')) clean = '+$clean';
    if (!RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(clean)) return false;
    return !clean.startsWith('+60') ||
        RegExp(r'^(?:\+601[02-9][0-9]{7}|\+6011[0-9]{8})$').hasMatch(clean);
  }

  bool _isStrongPassword(String password) =>
      password.length >= 8 &&
      RegExp(r'[A-Z]').hasMatch(password) &&
      RegExp(r'[a-z]').hasMatch(password) &&
      RegExp(r'[0-9]').hasMatch(password) &&
      RegExp(r'[^a-zA-Z0-9\s]').hasMatch(password);

  Future<void> _sendVerificationCode() async {
    if (isSendingCode) return;

    final ic = icController.text.trim();
    final phone = phoneController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (nameController.text.trim().isEmpty ||
        selectedSex == null ||
        selectedNationality == null ||
        ic.isEmpty ||
        phone.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showMessage('Please complete all required fields.');
      return;
    }

    if (selectedNationality != 'Malaysia' && selectedBirthDate == null) {
      _showMessage('Please enter your date of birth.');
      return;
    }
    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (!_isValidPhone(phone)) {
      _showMessage('Enter a valid mobile number, e.g. +60123456789.');
      return;
    }

    if (!_isStrongPassword(password)) {
      _showMessage(
        'Password needs at least 8 characters, uppercase, lowercase, a number and a symbol.',
      );
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
      final response = await AuthService.sendVerificationCode(
        email: email,
        phone: phoneController.text.trim(),
      );
      if (!mounted) return;

      setState(() {
        codeSent = true;
        codeVerified = false;
      });

      final message = response['message'] ?? 'TAC sent to your email.';
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

    if (nameController.text.trim().isEmpty ||
        selectedSex == null ||
        selectedNationality == null) {
      _showMessage('Please complete all required fields.');
      return;
    }
    if (!_isValidEmail(emailController.text) ||
        !_isValidPhone(phoneController.text) ||
        !_isStrongPassword(passwordController.text) ||
        passwordController.text != confirmPasswordController.text) {
      _showMessage('Please check your email, phone number and password.');
      return;
    }
    final code = codeController.text.trim();
    final email = emailController.text.trim();
    final ic = icController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text;

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      _showMessage('Please enter the 6-digit verification code.');
      return;
    }

    setState(() {
      isRegistering = true;
    });

    try {
      // Step 1: Verify 6-digit code
      await AuthService.verifyCode(email: email, code: code, phone: phone);

      // Step 2: Register account
      await AuthService.register(
        name: nameController.text.trim(),
        sexAtBirth: selectedSex!,
        nationality: selectedNationality!,
        dateOfBirth: selectedNationality == 'Malaysia'
            ? null
            : selectedBirthDate,
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
    if (isSendingCode || isRegistering) return;
    await _sendVerificationCode();
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
                          const Expanded(child: Center(child: BrandWordmark())),
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
                          LocalizedText(
                            'Create your account',
                            style: AppText.display,
                          ),
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
                            fieldLabel('Full Name'),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('signup-name'),
                              controller: nameController,
                              enabled: !codeSent,
                              textCapitalization: TextCapitalization.words,
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'Enter your full name',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(height: 18),
                            fieldLabel('Sex at Birth'),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              key: const ValueKey('signup-sex'),
                              initialValue: selectedSex,
                              style: AppText.input,
                              decoration: appInputDecoration(
                                hint: 'Select sex at birth',
                                icon: Icons.person_outline_rounded,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'male',
                                  child: LocalizedText('Male'),
                                ),
                                DropdownMenuItem(
                                  value: 'female',
                                  child: LocalizedText('Female'),
                                ),
                                DropdownMenuItem(
                                  value: 'intersex',
                                  child: LocalizedText('Intersex'),
                                ),
                              ],
                              onChanged: codeSent
                                  ? null
                                  : (value) =>
                                        setState(() => selectedSex = value),
                            ),
                            const SizedBox(height: 18),
                            fieldLabel('Nationality'),
                            const SizedBox(height: 8),
                            DropdownMenu<String>(
                              key: const ValueKey('signup-nationality'),
                              expandedInsets: EdgeInsets.zero,
                              enabled: !codeSent,
                              enableFilter: true,
                              requestFocusOnTap: true,
                              menuHeight: 280,
                              hintText: tr('Select a country'),
                              textStyle: AppText.input,
                              dropdownMenuEntries: registrationCountries
                                  .map(
                                    (country) => DropdownMenuEntry(
                                      value: country,
                                      label: tr(country),
                                    ),
                                  )
                                  .toList(),
                              onSelected: (value) =>
                                  setState(() => selectedNationality = value),
                            ),
                            const SizedBox(height: 18),
                            if (selectedNationality != null &&
                                selectedNationality != 'Malaysia') ...[
                              fieldLabel('Date of Birth'),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: codeSent
                                    ? null
                                    : () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              selectedBirthDate ??
                                              DateTime(2000),
                                          firstDate: DateTime(1900),
                                          lastDate: DateTime.now(),
                                        );
                                        if (date != null && mounted) {
                                          setState(
                                            () => selectedBirthDate = date,
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: LocalizedText(
                                  selectedBirthDate == null
                                      ? 'Select date of birth'
                                      : selectedBirthDate!
                                            .toIso8601String()
                                            .split('T')
                                            .first,
                                ),
                              ),
                              const SizedBox(height: 18),
                            ],
                            // IC NUMBER
                            fieldLabel(
                              selectedNationality != null &&
                                      selectedNationality != 'Malaysia'
                                  ? 'IC / Passport Number'
                                  : 'IC Number',
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: icController,
                              enabled: !codeSent,
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
                              key: const ValueKey('signup-phone'),
                              controller: phoneController,
                              enabled: !codeSent,
                              keyboardType: TextInputType.phone,
                              style: AppText.input,
                              decoration: _validatedDecoration(
                                value: phoneController.text,
                                valid: _isValidPhone(phoneController.text),
                                invalidMessage: 'Enter a valid mobile number, e.g. +60123456789.',
                                validMessage: 'Valid phone format.',
                                hint: 'e.g. +60123456789',
                                icon: Icons.phone_outlined,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // EMAIL ADDRESS
                            fieldLabel('Email Address'),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('signup-email'),
                              controller: emailController,
                              enabled: !codeSent,
                              keyboardType: TextInputType.emailAddress,
                              style: AppText.input,
                              decoration: _validatedDecoration(
                                value: emailController.text,
                                valid: _isValidEmail(emailController.text),
                                invalidMessage:
                                    'Please enter a valid email address.',
                                validMessage: 'Valid email format. Verify with email TAC.',
                                hint: 'e.g. user@example.com',
                                icon: Icons.email_outlined,
                              ),
                            ),

                            const SizedBox(height: 18),

                            // PASSWORD
                            fieldLabel('Password'),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('signup-password'),
                              controller: passwordController,
                              enabled: !codeSent,
                              obscureText: hidePassword,
                              style: AppText.input,
                              decoration: _validatedDecoration(
                                value: passwordController.text,
                                valid: _isStrongPassword(
                                  passwordController.text,
                                ),
                                invalidMessage:
                                    'Meet all password requirements below.',
                                validMessage: 'All password requirements met.',
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

                            _passwordCriterion(
                              'At least 8 characters',
                              passwordController.text.length >= 8,
                            ),
                            _passwordCriterion(
                              'One uppercase letter (A-Z)',
                              RegExp(r'[A-Z]')
                                  .hasMatch(passwordController.text),
                            ),
                            _passwordCriterion(
                              'One lowercase letter (a-z)',
                              RegExp(r'[a-z]')
                                  .hasMatch(passwordController.text),
                            ),
                            _passwordCriterion(
                              'One number (0-9)',
                              RegExp(r'[0-9]')
                                  .hasMatch(passwordController.text),
                            ),
                            _passwordCriterion(
                              'One symbol (e.g. !@#)',
                              RegExp(r'[^a-zA-Z0-9\s]')
                                  .hasMatch(passwordController.text),
                            ),

                            const SizedBox(height: 18),

                            // CONFIRM PASSWORD
                            fieldLabel('Confirm Password'),
                            const SizedBox(height: 8),
                            TextField(
                              key: const ValueKey('signup-confirmPassword'),
                              controller: confirmPasswordController,
                              enabled: !codeSent,
                              obscureText: hideConfirmPassword,
                              style: AppText.input,
                              decoration: _validatedDecoration(
                                value: confirmPasswordController.text,
                                valid:
                                    _isStrongPassword(
                                      passwordController.text,
                                    ) &&
                                    passwordController.text ==
                                        confirmPasswordController.text,
                                invalidMessage: 'Passwords must match and meet all requirements.',
                                validMessage: 'Passwords match.',
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
                                onPressed: (isSendingCode || !_credentialsValid)
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
                                        '${emailController.text}. Please check your inbox or spam folder.',
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

                              const SizedBox(height: 4),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _resendCode,
                                  child: Text(
                                    isSendingCode
                                        ? 'Sending...'
                                        : 'Resend Code',
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
                                onPressed:
                                    (isRegistering ||
                                        codeVerified ||
                                        !_credentialsValid)
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
                              'A 6-digit TAC is sent to your email address to verify it before account activation.',
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
