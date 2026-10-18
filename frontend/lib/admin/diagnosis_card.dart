import 'package:flutter/material.dart';

import '../theme.dart';
import 'patient_lookup.dart';

class DiagnosisCard extends StatefulWidget {
  final String visitId;
  const DiagnosisCard({super.key, required this.visitId});
  @override
  State<DiagnosisCard> createState() => _DiagnosisCardState();
}

class _DiagnosisCardState extends State<DiagnosisCard> {
  final diagnosis = TextEditingController();
  final treatment = TextEditingController();
  final medications = TextEditingController();
  final followUp = TextEditingController();
  bool loading = true;
  bool saving = false;
  bool release = false;
  bool loaded = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await PatientLookup.request(
        '/admin/visits/${widget.visitId}/diagnosis',
      );
      if (!mounted) return;
      final value = data['diagnosis'] as Map?;
      diagnosis.text = value?['diagnosis'] ?? '';
      treatment.text = value?['treatment_notes'] ?? '';
      medications.text = ((value?['medications'] as List?) ?? []).join('\n');
      followUp.text = value?['follow_up_instructions'] ?? '';
      release = value?['released_to_patient_at'] != null;
      loaded = true;
    } catch (_) {
      if (mounted) error = 'Could not load diagnosis and treatment.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    if (saving || !loaded) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await PatientLookup.request(
        '/admin/visits/${widget.visitId}/diagnosis',
        body: {
          'diagnosis': diagnosis.text.trim(),
          'treatment_notes': treatment.text.trim(),
          'medications': medications.text
              .split('\n')
              .map((v) => v.trim())
              .where((v) => v.isNotEmpty)
              .toList(),
          'follow_up_instructions': followUp.text.trim(),
          'release': release,
        },
      );
      if (mounted) showAppSnack(context, 'Diagnosis and treatment saved.');
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not save. Your edits have been kept; try again.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    diagnosis.dispose();
    treatment.dispose();
    medications.dispose();
    followUp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: cardDecoration(radius: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Diagnosis and treatment', style: AppText.heading),
        const SizedBox(height: 12),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Text(error!, style: const TextStyle(color: AppColors.red)),
        if (!loading && !loaded)
          TextButton(
            onPressed: () {
              setState(() {
                loading = true;
                error = null;
              });
              load();
            },
            child: const Text('Retry'),
          ),
        if (loaded) ...[
          for (final field in [
            (diagnosis, 'Diagnosis'),
            (treatment, 'Treatment notes'),
            (medications, 'Medications (one per line)'),
            (followUp, 'Follow-up instructions'),
          ]) ...[
            const SizedBox(height: 16),
            Text(field.$2, style: AppText.label),
            const SizedBox(height: 8),
            TextField(
              controller: field.$1,
              enabled: !saving,
              minLines: 1,
              maxLines: 5,
              decoration: appInputDecoration(
                hint: field.$2,
                icon: Icons.notes_rounded,
              ),
            ),
          ],
          Material(color: Colors.transparent, child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Release to patient'),
            subtitle: const Text('Drafts are visible only to hospital staff.'),
            value: release,
            onChanged: saving
                ? null
                : (value) => setState(() => release = value),
          )),
          PrimaryButton(
            label: saving ? 'Saving...' : 'Save diagnosis and treatment',
            icon: Icons.save_outlined,
            onPressed: saving ? null : save,
          ),
        ],
      ],
    ),
  );
}
