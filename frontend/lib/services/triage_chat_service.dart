import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';

/// One structured agent turn from POST /triage/chat.
class TriageChatReply {
  /// `text` (free-text reply) or `selection` (pick from [options]).
  final String type;
  final String? question;
  final String text;
  final List<String> options;

  /// Several options can be ticked; [exclusiveOptions] can only be ticked alone.
  final bool multiSelect;
  final List<String> exclusiveOptions;

  /// Options matching what the user already mentioned: shown pre-selected so
  /// they confirm with one tap.
  final List<String> suggestedOptions;

  /// The user's own words for their main problem, once the backend has
  /// identified one (null for greetings like "hi").
  final String? chiefComplaint;

  /// Short summary of the main symptom, set once the screening has a result.
  final String? mainSymptom;
  final String? sessionId;

  /// Id of the stored report (= session id), once a logged-in screening has a result.
  final String? reportId;

  /// Who the screening is for: 'self', 'other', or null when not known.
  final String? subject;
  final TriageAssessmentData? assessment;

  TriageChatReply({
    required this.type,
    required this.question,
    required this.text,
    required this.options,
    this.multiSelect = false,
    this.exclusiveOptions = const [],
    this.suggestedOptions = const [],
    this.chiefComplaint,
    this.mainSymptom,
    required this.sessionId,
    this.reportId,
    this.subject,
    required this.assessment,
  });

  bool get isSelection => type == 'selection' && options.isNotEmpty;

  factory TriageChatReply.fromJson(Map<String, dynamic> json) {
    final response = json['response'];
    final options = response is List
        ? response.map((e) => e.toString()).toList()
        : <String>[];
    return TriageChatReply(
      type: (json['type'] as String?) ?? 'text',
      question: json['question'] as String?,
      text: (json['reply'] as String?) ?? (response is String ? response : ''),
      options: options,
      multiSelect: json['multi_select'] == true,
      exclusiveOptions:
          List<String>.from(json['exclusive_options'] ?? const []),
      suggestedOptions:
          List<String>.from(json['suggested_options'] ?? const []),
      chiefComplaint: json['chief_complaint'] as String?,
      mainSymptom: json['main_symptom'] as String?,
      sessionId: json['session_id'] as String?,
      reportId: json['report_id'] as String?,
      subject: json['subject'] as String?,
      assessment: json['assessment'] == null
          ? null
          : TriageAssessmentData.fromJson(
              json['assessment'] as Map<String, dynamic>),
    );
  }
}

class TriageAssessmentData {
  final int level;
  final String urgencyDescription;
  final List<String> primaryConcerns;
  final List<String> immediateActions;

  TriageAssessmentData({
    required this.level,
    required this.urgencyDescription,
    required this.primaryConcerns,
    required this.immediateActions,
  });

  factory TriageAssessmentData.fromJson(Map<String, dynamic> json) {
    // triage_level looks like "LEVEL_2_EMERGENT"; the number is the source of truth.
    final match = RegExp(r'LEVEL_(\d)').firstMatch('${json['triage_level']}');
    return TriageAssessmentData(
      level: int.tryParse(match?.group(1) ?? '') ?? 3,
      urgencyDescription: (json['urgency_description'] as String?) ?? '',
      primaryConcerns: List<String>.from(json['primary_concerns'] ?? const []),
      immediateActions:
          List<String>.from(json['immediate_actions'] ?? const []),
    );
  }
}

class TriageChatService {
  static Future<TriageChatReply> sendMessage(
    String message, {
    String? sessionId,
    String? patientId,
    List<String>? selectedOptions,
    String? note,
  }) async {
    final res = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/triage/chat'),
          headers: ApiService.defaultHeaders,
          body: jsonEncode({
            'message': message,
            'session_id': ?sessionId,
            'patient_id': ?patientId,
            'selected_options': ?selectedOptions,
            'note': ?note,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('Triage service error (${res.statusCode})');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return TriageChatReply.fromJson(body['data'] as Map<String, dynamic>);
  }

  /// Links a stored report to the account of the person it was for, by IC.
  /// Returns null on success, or a message to show.
  static Future<String?> linkReportSubject(String reportId, String ic) async {
    try {
      final res = await http
          .put(
            Uri.parse('${ApiService.baseUrl}/triage/reports/$reportId/subject'),
            headers: ApiService.defaultHeaders,
            body: jsonEncode({'ic': ic}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      final detail = body is Map ? body['detail'] : null;
      return detail is String ? detail : 'Could not link the report. Please try again.';
    } catch (_) {
      return 'Could not reach the server. Please try again.';
    }
  }
}
