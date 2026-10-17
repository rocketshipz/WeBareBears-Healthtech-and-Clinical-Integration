import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_store.dart';
import 'admin_shell.dart';
import 'admin_i18n.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final staffIdController = TextEditingController();
  final passwordController = TextEditingController();

  bool obscure = true;
  String role = 'Nurse';

  static const hospitals = [
    'Central General Hospital',
    'Riverside Medical Centre',
    'Maple Community Hospital',
  ];

  String hospital = hospitals.first;

  @override
  void dispose() {
    staffIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = staffIdController.text.trim();
    final pw = passwordController.text;

    if (id.isEmpty || pw.isEmpty) {
      showAppSnack(context, tr('Please enter your staff ID and password.'));
      return;
    }

    try {
      await adminStore.signIn(id, pw, hospital: hospital, role: role);
    } catch (_) {
      if (!mounted) return;
      showAppSnack(context, tr('Sign in failed. Check your staff ID and password.'));
      return;
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeSlideIn(
                      index: 0,
                      child: Row(
                        children: [
                          CircleBackButton(onTap: () => Navigator.pop(context)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    const FadeSlideIn(
                      index: 1,
                      child: Center(child: BrandWordmark(size: 30)),
                    ),

                    const SizedBox(height: 26),

                    FadeSlideIn(
                      index: 2,
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          children: [
                            Text(
                              tr('Staff login'),
                              textAlign: TextAlign.center,
                              style: AppText.display,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('Sign in to update patient progress.'),
                              textAlign: TextAlign.center,
                              style: AppText.body,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    FadeSlideIn(
                      index: 3,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: cardDecoration(radius: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            fieldLabel(tr('Hospital')),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: hospital,
                              isExpanded: true,
                              style: AppText.input,
                              borderRadius: BorderRadius.circular(16),
                              decoration: appInputDecoration(
                                hint: tr('Select hospital'),
                                icon: Icons.local_hospital_outlined,
                              ),
                              items: [
                                for (final h in hospitals)
                                  DropdownMenuItem(value: h, child: Text(h)),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => hospital = value);
                                }
                              },
                            ),

                            const SizedBox(height: 18),

                            fieldLabel(tr('Role')),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final r in const ['Nurse', 'Doctor', 'Admin'])
                                  SelectChip(
                                    label: tr(r),
                                    selected: role == r,
                                    onTap: () => setState(() => role = r),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 18),

                            fieldLabel(tr('Staff ID')),
                            const SizedBox(height: 8),
                            TextField(
                              controller: staffIdController,
                              style: AppText.input,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              decoration: appInputDecoration(
                                hint: tr('e.g. N-1021'),
                                icon: Icons.badge_outlined,
                              ),
                            ),

                            const SizedBox(height: 18),

                            fieldLabel(tr('Password')),
                            const SizedBox(height: 8),
                            TextField(
                              controller: passwordController,
                              obscureText: obscure,
                              style: AppText.input,
                              onSubmitted: (_) => _login(),
                              decoration: appInputDecoration(
                                hint: tr('Enter your password'),
                                icon: Icons.lock_outline_rounded,
                                suffix: IconButton(
                                  icon: Icon(
                                    obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.grey,
                                  ),
                                  onPressed: () =>
                                      setState(() => obscure = !obscure),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            PrimaryButton(
                              label: tr('Log in'),
                              icon: Icons.arrow_forward_rounded,
                              onPressed: _login,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Center(
                      child: Text(
                        tr('Prototype: any staff ID and password will work.'),
                        style: AppText.caption,
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