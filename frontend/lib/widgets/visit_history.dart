import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../admin/patient_lookup.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';

class VisitHistory extends StatefulWidget {
  final String? patientId;
  final int revision;
  const VisitHistory({super.key, this.patientId, this.revision = 0});

  @override
  State<VisitHistory> createState() => _VisitHistoryState();
}

class _VisitHistoryState extends State<VisitHistory> {
  List<Map<String, dynamic>> entries = [];
  bool loading = false;
  bool expanded = false;
  String? error;

  @override
  void didUpdateWidget(covariant VisitHistory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (expanded &&
        (oldWidget.revision != widget.revision ||
            oldWidget.patientId != widget.patientId)) {
      load();
    }
  }

  Future<void> load() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final token = widget.patientId == null
          ? AuthService.token
          : PatientLookup.token;
      if (token == null) throw Exception('Please log in to view history.');
      final path = widget.patientId == null
          ? '/progress/history'
          : '/admin/patients/${Uri.encodeComponent(widget.patientId!)}/history';
      final response = await http
          .get(
            Uri.parse('${ApiService.baseUrl}$path'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Could not load visit history.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted) {
        setState(
          () => entries = (data['history'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not load visit history. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String date(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (parsed == null) return 'Not recorded';
    final locale = MaterialLocalizations.of(context);
    return '${locale.formatFullDate(parsed)} ? ${locale.formatTimeOfDay(TimeOfDay.fromDateTime(parsed))}';
  }

  Widget detail(String label, dynamic value) {
    final text = value is List ? value.join(', ') : value?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '$label: ${text.trim().isEmpty ? 'Not recorded' : text}',
        style: AppText.body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: cardDecoration(radius: 24),
    child: Material(
      color: Colors.transparent,
      child: ExpansionTile(
        leading: const Icon(Icons.history, color: AppColors.darkTeal),
        title: Text('History', style: AppText.heading),
        subtitle: const Text('Completed hospital visits'),
        onExpansionChanged: (value) {
          expanded = value;
          if (value) load();
        },
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text(error!, style: AppText.body),
          if (!loading && error == null && entries.isEmpty)
            Text('No completed visits yet.', style: AppText.body),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry['hospital']?.toString() ?? 'Hospital',
                    style: AppText.bodyStrong,
                  ),
                  detail('Department', entry['department']),
                  detail('Visit date', date(entry['arrived_at'])),
                  detail('Checked out', date(entry['completed_at'])),
                  detail('Outcome', entry['outcome']),
                  detail('Diagnosis', entry['diagnosis']),
                  detail('Medications', entry['medications']),
                  detail('Treatment', entry['treatment_notes']),
                  detail('Follow-up', entry['follow_up_instructions']),
                  const Divider(),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: loading ? null : load,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh history'),
          ),
        ],
      ),
    ),
  );
}
