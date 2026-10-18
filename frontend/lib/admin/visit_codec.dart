import 'dart:convert';

import 'admin_models.dart';

DateTime? visitDate(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();
String stepStatus(StepStatus status) => switch (status) {
  StepStatus.waiting => 'waiting',
  StepStatus.inProgress => 'in_progress',
  StepStatus.done => 'done',
};
StepStatus readStatus(dynamic value) => switch (value) {
  'done' || 'completed' => StepStatus.done,
  'in_progress' || 'inProgress' => StepStatus.inProgress,
  _ => StepStatus.waiting,
};

Visit decodeVisit(Map<String, dynamic> data) {
  final profile = Map<String, dynamic>.from(data['profile'] as Map? ?? {});
  final steps = <VisitStep>[];
  for (final raw in data['steps'] as List? ?? []) {
    final step = VisitStep.fromKey(
      key: raw['id'],
      name: raw['name'],
      isTest: raw['is_test'] == true,
    );
    step.status = readStatus(raw['status']);
    step.startedAt = visitDate(raw['started_at']);
    step.completedAt = visitDate(raw['completed_at']);
    step.note = raw['note']?.toString() ?? '';
    for (final result in raw['results'] as List? ?? []) {
      step.results.add(
        TestResult(
          id: result['id'],
          stepKey: step.id,
          fileName: result['file_name'],
          pages: result['pages'] ?? 1,
          uploadedAt: visitDate(result['uploaded_at']) ?? DateTime.now(),
          staffId: result['staff_id'] ?? '',
          staffName: result['staff_name'] ?? '',
          bytes: result['bytes_base64'] == null
              ? null
              : base64Decode(result['bytes_base64']),
        ),
      );
    }
    steps.add(step);
  }
  final visit = Visit(
    id: data['id'],
    queueNo: data['queue_no'] ?? '',
    patientId: data['patient_id'],
    triageReportId: data['triage_report_id'],
    assignedStaffId: data['assigned_staff_id'],
    name: profile['name'] ?? 'Patient',
    ic: profile['ic'] ?? '',
    age: (profile['age'] as num?)?.toInt() ?? 0,
    sex: profile['sex_at_birth'] ?? 'Unspecified',
    complaint: data['complaint'] ?? '',
    acuity: Acuity.values.firstWhere(
      (a) => a.name == data['acuity'],
      orElse: () => Acuity.green,
    ),
    hospital: data['hospital'] ?? '',
    hospitalId: data['hospital_id'],
    department: data['department'] ?? '',
    arrivedAt: visitDate(data['arrived_at']) ?? DateTime.now(),
    steps: steps,
    profile: profile,
    patientPhone: profile['phone'] ?? '',
    bloodType: profile['blood_type'] ?? '',
    allergies: profile['allergies']?.toString() ?? '',
    conditions: profile['chronic_conditions']?.toString() ?? '',
    medication: profile['current_medications']?.toString() ?? '',
    triage: data['triage'] == null
        ? null
        : TriageSummary.fromJson(Map<String, dynamic>.from(data['triage'])),
    outcome: data['outcome'],
    completedAt: visitDate(data['completed_at']),
    version: data['version'] ?? 0,
    familySharing: data['family_sharing'] == true,
    shareToken: data['share_token'],
  );
  for (final entry in data['logs'] as List? ?? []) {
    visit.log.add(
      LogEntry(
        id: entry['id'],
        text: entry['text'] ?? '',
        staffId: entry['staff_id'] ?? '',
        staffName: entry['staff_name'] ?? '',
        time: visitDate(entry['time']) ?? DateTime.now(),
        stepId: entry['step_id'],
        from: entry['from'] == null ? null : readStatus(entry['from']),
        to: entry['to'] == null ? null : readStatus(entry['to']),
        isUndoRecord: entry['is_undo_record'] == true,
        undone: entry['undone'] == true,
      ),
    );
  }
  return visit;
}

Map<String, dynamic> encodeVisit(Visit visit) => {
  'patient_id': visit.patientId,
  'ic': visit.ic,
  'triage_report_id': visit.triageReportId,
  'acuity': visit.acuity.name,
  'complaint': visit.complaint,
  'version': visit.version,
  'outcome': visit.outcome,
  'family_sharing': visit.familySharing,
  'share_token': visit.shareToken,
  'steps': [
    for (final step in visit.steps)
      {
        'id': step.id,
        'name': step.name,
        'is_test': step.isTest,
        'status': stepStatus(step.status),
        'started_at': step.startedAt?.toUtc().toIso8601String(),
        'completed_at': step.completedAt?.toUtc().toIso8601String(),
        'note': step.note,
        'results': [
          for (final result in step.results)
            {
              'id': result.id,
              'file_name': result.fileName,
              'pages': result.pages,
              'uploaded_at': result.uploadedAt.toUtc().toIso8601String(),
              'staff_id': result.staffId,
              'staff_name': result.staffName,
              if (result.bytes != null)
                'bytes_base64': base64Encode(result.bytes!),
            },
        ],
      },
  ],
  'logs': [
    for (final entry in visit.log)
      {
        'id': entry.id,
        'text': entry.text,
        'step_id': entry.stepId,
        'from': entry.from == null ? null : stepStatus(entry.from!),
        'to': entry.to == null ? null : stepStatus(entry.to!),
        'is_undo_record': entry.isUndoRecord,
        'undone': entry.undone,
      },
  ],
};
