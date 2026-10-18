import 'package:flutter/material.dart';

import '../admin/admin_login.dart';
import '../localization.dart';
import '../theme.dart';
import 'login_screen.dart';

/// Shared entry point before either authentication flow.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandWordmark(),
                    const SizedBox(height: 32),
                    Text('Welcome to TriageMY', style: AppText.display,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Text('Choose how you want to continue.',
                        style: AppText.body, textAlign: TextAlign.center),
                    const SizedBox(height: 32),
                    _role(context, icon: Icons.person_outline_rounded,
                        title: 'Normal user',
                        description: 'Log in or sign up as a patient.',
                        destination: const LoginScreen()),
                    const SizedBox(height: 16),
                    _role(context, icon: Icons.local_hospital_outlined,
                        title: 'Admin',
                        description: 'Log in to the hospital staff portal.',
                        destination: const AdminLoginScreen()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _role(BuildContext context, {required IconData icon,
      required String title, required String description,
      required Widget destination}) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => destination),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Icon(icon, size: 32, color: AppColors.darkTeal),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(title, style: AppText.heading),
                  const SizedBox(height: 4),
                  LocalizedText(description, style: AppText.body),
                ],
              )),
              const Icon(Icons.chevron_right, color: AppColors.darkTeal),
            ],
          ),
        ),
      ),
    );
  }
}
