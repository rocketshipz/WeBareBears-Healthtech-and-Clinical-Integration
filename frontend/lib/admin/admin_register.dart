import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_store.dart';
import 'patient_lookup.dart';
import 'patient_profile_card.dart';

class RegisterPatientPage extends StatefulWidget {
  final ValueChanged<Visit> onRegistered;
  const RegisterPatientPage({super.key, required this.onRegistered});
  @override
  State<RegisterPatientPage> createState() => _RegisterPatientPageState();
}

class _RegisterPatientPageState extends State<RegisterPatientPage> {
  final icController = TextEditingController();
  Map<String, dynamic>? patient;
  bool loading = false;
  String? error;
  @override
  void dispose() {
    icController.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (loading) return;
    final ic = icController.text.replaceAll(RegExp(r'[-\s]'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(ic)) {
      setState(() {
        patient = null;
        error = 'Enter a valid 12-digit IC number.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
      patient = null;
    });
    try {
      final result = await PatientLookup.request('/admin/patients?ic=$ic');
      if (mounted) setState(() => patient = result);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _register() async {
    final data = patient;
    if (data == null || loading) return;
    final profile = Map<String, dynamic>.from(data['profile'] as Map);
    if (adminStore.active.any((v) => v.patientId == profile['id'])) {
      showAppSnack(context, 'This patient is already in the queue.');
      return;
    }
    final triage = data['triage'] == null
        ? null
        : TriageSummary.fromJson(
            Map<String, dynamic>.from(data['triage'] as Map),
          );
    setState(() => loading = true);
    try {
      final visit = await adminStore.registerPatient(
        name: profile['name']?.toString() ?? 'Patient',
        ic: profile['ic'].toString(),
        age: (profile['age'] as num).toInt(),
        sex: profile['sex_at_birth']?.toString() ?? 'Unspecified',
        complaint: triage?.symptom ?? 'Awaiting nurse assessment',
        acuity: Acuity.pending,
        tests: const [],
        patientPhone: profile['phone']?.toString() ?? '',
        profile: profile,
        triage: triage,
        triageReportId: data['report_id'] as String?,
      );
      if (!mounted) return;
      setState(() {
        patient = null;
        icController.clear();
      });
      widget.onRegistered(visit);
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GradientBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandWordmark(size: 28),
                  const SizedBox(height: 26),
                  Text('Patient Check-In', style: AppText.display),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the patient IC to retrieve their profile and latest saved triage report.',
                    style: AppText.body,
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: icController,
                    enabled: !loading,
                    keyboardType: TextInputType.number,
                    onSubmitted: (_) => _lookup(),
                    onChanged: (_) => setState(() {
                      patient = null;
                      error = null;
                    }),
                    decoration: appInputDecoration(
                      hint: 'IC number, e.g. 000101-00-0000',
                      icon: Icons.badge_outlined,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: loading ? 'Loading...' : 'Find patient',
                    icon: Icons.search,
                    onPressed: loading ? null : _lookup,
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.red),
                      ),
                    ),
                  if (patient != null) ...[
                    const SizedBox(height: 20),
                    PrimaryButton(
                      label: loading ? 'Checking in...' : 'Check in patient',
                      icon: Icons.arrow_forward,
                      onPressed: loading ? null : _register,
                    ),
                    const SizedBox(height: 20),
                    PatientProfileCard(
                      profile: Map<String, dynamic>.from(
                        patient!['profile'] as Map,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (patient!['triage'] != null)
                      PatientProfileCard(
                        title: 'Latest triage report',
                        profile: Map<String, dynamic>.from(
                          patient!['triage'] as Map,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
