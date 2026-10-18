import 'package:flutter/material.dart';

import '../theme.dart';
import 'patient_lookup.dart';

class ChangeStaffPassword extends StatefulWidget {
  const ChangeStaffPassword({super.key});
  @override
  State<ChangeStaffPassword> createState() => _ChangeStaffPasswordState();
}

class _ChangeStaffPasswordState extends State<ChangeStaffPassword> {
  final current = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool saving = false;
  String? error;

  @override
  void dispose() {
    current.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving) return;
    if (current.text.isEmpty ||
        password.text.length < 8 ||
        password.text.length > 128) {
      setState(
        () => error = 'Enter your current password and a new password of 8–128 characters.',
      );
      return;
    }
    if (password.text != confirmation.text) {
      setState(() => error = 'New passwords do not match.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await PatientLookup.request(
        '/admin/change-password',
        body: {'current_password': current.text, 'new_password': password.text},
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnack(context, 'Password changed successfully.');
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar('Change password'),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final field in [
                (current, 'Current password'),
                (password, 'New password'),
                (confirmation, 'Confirm new password'),
              ]) ...[
                Text(field.$2, style: AppText.label),
                const SizedBox(height: 8),
                TextField(
                  controller: field.$1,
                  obscureText: true,
                  enabled: !saving,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: appInputDecoration(
                    hint: field.$2,
                    icon: Icons.lock_outline,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: AppColors.red),
                  ),
                ),
              PrimaryButton(
                label: saving ? 'Saving...' : 'Change password',
                icon: Icons.lock_reset,
                onPressed: saving ? null : save,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
