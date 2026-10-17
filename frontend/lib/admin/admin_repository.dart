import 'dart:typed_data';

import 'admin_models.dart';

/// Where hospital data is loaded from and saved to.
/// [AdminStore] talks only to this interface, so the backend can be swapped.
abstract class AdminRepository {
  /// True when running on sample data with nothing saved.
  bool get isDemo;

  Future<StaffMember> signIn(
    String staffId,
    String password, {
    String? hospital,
    String? role,
  });

  Future<void> signOut();

  /// Calls [onChange] whenever data for [hospital] changes.
  /// Returns a function that stops listening.
  void Function() listen(String hospital, void Function() onChange);

  Future<List<Visit>> loadVisits(String hospital);

  Future<List<IncomingPatient>> loadIncoming(String hospital);

  Future<String> nextQueueNo(String hospital);

  Future<void> saveVisit(
    Visit v, {
    List<LogEntry> newLogs = const [],
    List<LogEntry> updatedLogs = const [],
  });

  Future<void> deleteStep(Visit v, VisitStep step);

  Future<TestResult> uploadResult({
    required Visit visit,
    required VisitStep step,
    required Uint8List bytes,
    required String fileName,
    required int pages,
    required StaffMember staff,
  });

  Future<Uint8List> downloadResult(TestResult r);
}

/// In-memory repository: sample data only, nothing leaves the device.
class DemoAdminRepository implements AdminRepository {
  int _queueCounter = 130;

  @override
  bool get isDemo => true;

  @override
  Future<StaffMember> signIn(
    String staffId,
    String password, {
    String? hospital,
    String? role,
  }) async {
    // Demo: any non-empty credentials are accepted.
    final id = staffId.trim().toUpperCase();

    return StaffMember(
      id: id,
      name: demoStaffNames[id] ?? 'Staff $id',
      role: role ?? 'Nurse',
      hospital: hospital ?? 'Central General Hospital',
      department: 'Emergency Department',
    );
  }

  @override
  Future<void> signOut() async {}

  @override
  void Function() listen(String hospital, void Function() onChange) {
    return () {};
  }

  @override
  Future<List<Visit>> loadVisits(String hospital) async => const [];

  @override
  Future<List<IncomingPatient>> loadIncoming(String hospital) async {
    final now = DateTime.now();

    return [
      IncomingPatient(
        reportId: 'demo-report-1',
        name: 'Siti Nurhaliza',
        ic: '890215-08-4412',
        age: 36,
        sex: 'Female',
        bloodType: 'AB+',
        allergies: 'None',
        phone: '0176543210',
        emergencyPhone: '0198765432',
        etaMinutes: 12,
        triage: TriageSummary(
          symptom: 'Abdominal pain',
          severity: 'Moderate',
          duration: 'Less than 24 hours',
          dangerSigns: const [],
          level: 3,
          submittedAt: now.subtract(const Duration(minutes: 8)),
        ),
      ),
    ];
  }

  @override
  Future<String> nextQueueNo(String hospital) async => 'A${_queueCounter++}';

  @override
  Future<void> saveVisit(
    Visit v, {
    List<LogEntry> newLogs = const [],
    List<LogEntry> updatedLogs = const [],
  }) async {}

  @override
  Future<void> deleteStep(Visit v, VisitStep step) async {}

  @override
  Future<TestResult> uploadResult({
    required Visit visit,
    required VisitStep step,
    required Uint8List bytes,
    required String fileName,
    required int pages,
    required StaffMember staff,
  }) async {
    return TestResult(
      id: newId(),
      stepKey: step.id,
      fileName: fileName,
      pages: pages,
      uploadedAt: DateTime.now(),
      staffId: staff.id,
      staffName: staff.name,
      bytes: bytes,
    );
  }

  @override
  Future<Uint8List> downloadResult(TestResult r) async {
    final bytes = r.bytes;
    if (bytes == null) throw StateError('Result not available in demo mode');
    return bytes;
  }
}
