import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_config.dart';
import 'admin_i18n.dart';

// ============================================================
// SMALL HELPERS
// ============================================================

/// Random v4 UUID (so new rows can be created offline-first).
String newId() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;

  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');

  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-'
      '${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}

/// Long unguessable token for the progress tracking link.
String newShareToken() {
  final r = Random.secure();
  final bytes = List<int>.generate(18, (_) => r.nextInt(256));

  return base64Url.encode(bytes).replaceAll('=', '');
}

/// Demo staff directory (real names come from the `staff` table in Supabase).
const Map<String, String> demoStaffNames = {
  'N-1021': 'Aina Hassan',
  'N-1034': 'Farah Zulkifli',
  'D-2001': 'Dr. Tan Wei Ming',
};

// ============================================================
// ENUMS
// ============================================================

enum StepStatus { waiting, inProgress, done }

enum Acuity { red, yellow, green, pending }

extension AcuityX on Acuity {
  /// English wording, used for stored data such as log entries.
  String get labelEn {
    switch (this) {
      case Acuity.pending:
        return 'Pending Triage';
      case Acuity.red:
        return 'Red';
      case Acuity.yellow:
        return 'Yellow';
      case Acuity.green:
        return 'Green';
    }
  }

  String get descriptionEn {
    switch (this) {
      case Acuity.pending:
        return 'Awaiting zone assignment';
      case Acuity.red:
        return 'Critical';
      case Acuity.yellow:
        return 'Urgent';
      case Acuity.green:
        return 'Non-urgent';
    }
  }

  /// Wording in the current language, for display.
  String get label => tr(labelEn);

  String get description => tr(descriptionEn);

  Color get color {
    switch (this) {
      case Acuity.pending:
        return AppColors.grey;
      case Acuity.red:
        return AppColors.red;
      case Acuity.yellow:
        return AppColors.yellow;
      case Acuity.green:
        return AppColors.green;
    }
  }

  /// Used to sort the queue: most urgent first.
  int get rank {
    switch (this) {
      case Acuity.pending:
        return 3;
      case Acuity.red:
        return 0;
      case Acuity.yellow:
        return 1;
      case Acuity.green:
        return 2;
    }
  }
}

// ============================================================
// TEST RESULT DOCUMENT  (scanned paper result, stored as PDF)
// ============================================================

class TestResult {
  final String id;
  final String stepKey;
  final String fileName;

  /// Path inside the Supabase Storage bucket (null in demo mode).
  final String? storagePath;

  /// Kept in memory right after upload (and in demo mode).
  Uint8List? bytes;

  final int pages;
  final DateTime uploadedAt;
  final String staffId;
  final String staffName;

  TestResult({
    required this.id,
    required this.stepKey,
    required this.fileName,
    required this.pages,
    required this.uploadedAt,
    required this.staffId,
    required this.staffName,
    this.storagePath,
    this.bytes,
  });
}

// ============================================================
// STEP  (one stage of the patient's visit)
// ============================================================

class VisitStep {
  final String id;

  /// Staff can rename tests; [id] stays the same so the audit trail still matches.
  String name;
  final IconData icon;

  /// Tests (blood test, X-ray...) can be added / removed by staff.
  final bool isTest;

  StepStatus status;
  DateTime? startedAt;
  DateTime? completedAt;
  String note;

  /// Scanned result documents attached to this test.
  final List<TestResult> results = [];

  VisitStep({
    required this.id,
    required this.name,
    required this.icon,
    this.isTest = false,
    this.status = StepStatus.waiting,
    this.startedAt,
    this.completedAt,
    this.note = '',
  });

  /// [name] in the current language (stored names stay in English).
  String get displayName => tr(name);

  /// Wording matches the patient-side "Progress Tracking" screen.
  String get title {
    final n = {'name': displayName};
    switch (status) {
      case StepStatus.done:
        return tr('{name} completed', n);
      case StepStatus.inProgress:
        return tr('{name} in progress', n);
      case StepStatus.waiting:
        return tr('{name} pending', n);
    }
  }

  String get statusText {
    final n = {'name': displayName};
    switch (status) {
      case StepStatus.done:
        return tr('{name} completed', n);
      case StepStatus.inProgress:
        return tr('{name} in progress', n);
      case StepStatus.waiting:
        return tr('Waiting for {name}', n);
    }
  }

  String get pillText {
    switch (status) {
      case StepStatus.done:
        return tr('Done');
      case StepStatus.inProgress:
        return tr('In progress');
      case StepStatus.waiting:
        return tr('Waiting');
    }
  }

  /// What the nurse taps to move this step forward.
  String get actionLabel {
    final n = {'name': displayName};
    switch (status) {
      case StepStatus.waiting:
        return tr('Start {name}', n);
      case StepStatus.inProgress:
        return tr('Mark {name} completed', n);
      case StepStatus.done:
        return tr('{name} completed', n);
    }
  }

  static VisitStep registration() => VisitStep(
    id: 'registration',
    name: 'Registration',
    icon: Icons.assignment_ind_outlined,
  );

  static VisitStep triage() => VisitStep(
    id: 'triage',
    name: 'Triage',
    icon: Icons.monitor_heart_outlined,
  );

  static VisitStep doctor() => VisitStep(
    id: 'doctor',
    name: 'Doctor consultation',
    icon: Icons.medical_services_outlined,
  );

  static VisitStep discharge() => VisitStep(
    id: 'discharge',
    name: 'Discharge / admission decision',
    icon: Icons.exit_to_app_rounded,
  );

  static String slug(String s) => s.toLowerCase().replaceAll(' ', '_');

  static VisitStep test(String name) => VisitStep(
    id: slug(name),
    name: name,
    icon: testCatalog[name] ?? Icons.science_outlined,
    isTest: true,
  );

  /// Rebuilds a step coming from the database.
  static VisitStep fromKey({
    required String key,
    required String name,
    required bool isTest,
  }) {
    switch (key) {
      case 'registration':
        return registration();
      case 'triage':
        return triage();
      case 'doctor':
        return doctor();
      case 'discharge':
        return discharge();
    }

    return VisitStep(
      id: key,
      name: name,
      icon: testCatalog[name] ?? Icons.science_outlined,
      isTest: isTest,
    );
  }

  /// Tests staff can add to a visit.
  static const Map<String, IconData> testCatalog = {
    'Blood test': Icons.bloodtype_outlined,
    'X-ray': Icons.image_search_outlined,
    'CT scan': Icons.donut_large_outlined,
    'ECG': Icons.monitor_heart_outlined,
    'Ultrasound': Icons.waves_outlined,
  };
}

// ============================================================
// LOG ENTRY  (audit trail + undo)
// ============================================================

class LogEntry {
  final String id;
  final String text;
  final String staffId;
  final String staffName;
  final DateTime time;

  /// Set for stage changes, so the latest one can be undone.
  final String? stepId;
  final StepStatus? from;
  final StepStatus? to;

  /// This entry records an undo (kept so the audit trail is never erased).
  final bool isUndoRecord;

  /// A stage change that was later undone.
  bool undone;

  LogEntry({
    String? id,
    required this.text,
    required this.staffId,
    required this.staffName,
    required this.time,
    this.stepId,
    this.from,
    this.to,
    this.isUndoRecord = false,
    this.undone = false,
  }) : id = id ?? newId();

  bool get undoable => stepId != null && from != null && to != null;

  /// "Aina Hassan · N-1021"
  String get by => '$staffName · $staffId';
}

// ============================================================
// TRIAGE SUMMARY  (what the patient submitted in the user app)
// ============================================================

class TriageSummary {
  final String symptom;
  final String severity;
  final String duration;
  final List<String> dangerSigns;
  final int level;
  final DateTime submittedAt;

  const TriageSummary({
    required this.symptom,
    required this.severity,
    required this.duration,
    required this.dangerSigns,
    required this.level,
    required this.submittedAt,
  });

  Acuity get acuity {
    if (level <= 1) return Acuity.red;
    if (level <= 3) return Acuity.yellow;
    return Acuity.green;
  }

  String get zoneLabel =>
      tr('{zone} Zone · Level {level}', {'zone': acuity.label, 'level': level});

  Map<String, dynamic> toJson() => {
    'symptom': symptom,
    'severity': severity,
    'duration': duration,
    'danger_signs': dangerSigns,
    'level': level,
    'submitted_at': submittedAt.toUtc().toIso8601String(),
  };

  factory TriageSummary.fromJson(Map<String, dynamic> j) => TriageSummary(
    symptom: (j['symptom'] ?? 'Not specified').toString(),
    severity: (j['severity'] ?? 'Not specified').toString(),
    duration: (j['duration'] ?? 'Not specified').toString(),
    dangerSigns: ((j['danger_signs'] ?? const []) as List)
        .map((e) => e.toString())
        .toList(),
    level: (j['level'] as num?)?.toInt() ?? 4,
    submittedAt: j['submitted_at'] == null
        ? DateTime.now()
        : DateTime.parse(j['submitted_at'].toString()).toLocal(),
  );
}

// ============================================================
// INCOMING PATIENT  (finished triage in the patient app, heading here)
// ============================================================

class IncomingPatient {
  final String reportId;
  final String? patientId;
  final String name;
  final String ic;
  final int age;
  final String sex;
  final String bloodType;
  final String allergies;
  final String conditions;
  final String medication;

  /// The patient's own phone number; the tracking link is sent here.
  final String phone;
  final String emergencyPhone;
  final int? etaMinutes;
  final TriageSummary triage;

  const IncomingPatient({
    required this.reportId,
    required this.name,
    required this.ic,
    required this.age,
    required this.sex,
    required this.triage,
    this.patientId,
    this.bloodType = '',
    this.allergies = '',
    this.conditions = '',
    this.medication = '',
    this.phone = '',
    this.emergencyPhone = '',
    this.etaMinutes,
  });
}

// ============================================================
// VISIT
// ============================================================

class Visit {
  final String id;
  String queueNo;
  int version;
  final String? patientId;
  final String? triageReportId;
  final String? assignedStaffId;

  String name;
  String ic;
  int age;
  String sex;
  String complaint;
  Acuity acuity;

  final String department;
  final String hospital;
  final String? hospitalId;
  final DateTime arrivedAt;
  final List<VisitStep> steps;
  final List<LogEntry> log = [];

  // clinical info carried over from the patient's profile
  Map<String, dynamic> profile;
  String bloodType;
  String allergies;
  String conditions;
  String medication;

  /// The patient's own triage submission (null for walk-ins).
  TriageSummary? triage;

  bool familySharing;
  String shareToken;

  /// The patient's own number; the live tracking link is sent here and the
  /// patient can pass it on to family.
  String patientPhone;

  String? diagnosis;
  String? outcome;
  DateTime? completedAt;

  Visit({
    String? id,
    required this.queueNo,
    this.version = 0,
    required this.name,
    required this.ic,
    required this.age,
    required this.sex,
    required this.complaint,
    required this.acuity,
    required this.department,
    required this.hospital,
    required this.arrivedAt,
    this.hospitalId,
    required this.steps,
    String? shareToken,
    this.patientId,
    this.triageReportId,
    this.assignedStaffId,
    this.triage,
    this.bloodType = '',
    this.allergies = '',
    this.conditions = '',
    this.medication = '',
    this.profile = const {},
    this.familySharing = false,
    this.patientPhone = '',
    this.diagnosis,
    this.outcome,
    this.completedAt,
  }) : id = id ?? newId(),
       shareToken = shareToken ?? newShareToken();

  String get shareLink => AdminConfig.shareLink(shareToken);

  VisitStep? get currentStep {
    if (isComplete) return null;
    for (final s in steps) {
      if (s.status != StepStatus.done) return s;
    }
    return null;
  }

  bool get isComplete =>
      steps.any((s) => s.id == 'discharge' && s.status == StepStatus.done);

  int get doneCount => steps.where((s) => s.status == StepStatus.done).length;

  String get statusText {
    final c = currentStep;
    if (c == null) {
      return isComplete
          ? tr(outcome ?? 'Visit completed')
          : tr('Awaiting next stage');
    }
    return c.statusText;
  }

  DateTime get lastUpdated => log.isEmpty ? arrivedAt : log.last.time;

  /// The newest stage change that can still be undone.
  LogEntry? get lastUndoable {
    for (final e in log.reversed) {
      if (e.isUndoRecord || e.undone) continue;
      return e.undoable ? e : null;
    }
    return null;
  }

  bool get canUndo => lastUndoable != null;

  /// Copies fresh data from the server into this (already displayed) object.
  void updateFrom(Visit o) {
    queueNo = o.queueNo;
    version = o.version;
    profile = o.profile;
    name = o.name;
    ic = o.ic;
    age = o.age;
    sex = o.sex;
    complaint = o.complaint;
    acuity = o.acuity;
    bloodType = o.bloodType;
    allergies = o.allergies;
    conditions = o.conditions;
    medication = o.medication;
    triage = o.triage;
    familySharing = o.familySharing;
    shareToken = o.shareToken;
    patientPhone = o.patientPhone;
    diagnosis = o.diagnosis;
    outcome = o.outcome;
    completedAt = o.completedAt;

    steps
      ..clear()
      ..addAll(o.steps);
    log
      ..clear()
      ..addAll(o.log);
  }
}

class StaffMember {
  final String id;
  final String name;
  final String role;
  final String hospital;
  final String? hospitalId;
  final String department;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.hospital,
    required this.department,
    this.hospitalId,
  });

  /// "Aina Hassan (N-1021)"
  String get label => '$name ($id)';
}
