import 'dart:async';
import 'dart:typed_data';

import 'admin_models.dart';
import 'admin_repository.dart';
import 'patient_lookup.dart';
import 'visit_codec.dart';

class ApiAdminRepository implements AdminRepository {
  final Map<String, Future<void>> _writes = {};
  bool get hasPendingWrites => _writes.isNotEmpty;
  @override
  bool get isDemo => false;
  @override
  Future<StaffMember> signIn(
    String staffId,
    String password, {
    String? hospital,
    String? role,
  }) =>
      throw UnsupportedError('Staff authentication is handled by AdminStore.');
  @override
  Future<void> signOut() async {
    await Future.wait(_writes.values);
  }

  @override
  void Function() listen(String hospital, void Function() onChange) {
    final timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!hasPendingWrites) onChange();
    });
    return timer.cancel;
  }

  @override
  Future<List<Visit>> loadVisits(String hospital) async {
    final response = await PatientLookup.request('/admin/visits');
    return [
      for (final visit in response['visits'])
        decodeVisit(Map<String, dynamic>.from(visit)),
    ];
  }

  @override
  Future<List<IncomingPatient>> loadIncoming(String hospital) async => [];
  @override
  Future<String> nextQueueNo(String hospital) async => 'Pending';
  @override
  Future<void> saveVisit(
    Visit v, {
    List<LogEntry> newLogs = const [],
    List<LogEntry> updatedLogs = const [],
  }) async {
    final payload = encodeVisit(v);
    final previous = _writes[v.id];
    final write = () async {
      if (previous != null) await previous;
      payload['version'] = v.version;
      final saved = await PatientLookup.request(
        '/admin/visits/${Uri.encodeComponent(v.id)}',
        body: payload,
      );
      v.version = saved['version'];
      v.queueNo = saved['queue_no'];
    }();
    _writes[v.id] = write;
    try {
      await write;
    } finally {
      if (identical(_writes[v.id], write)) _writes.remove(v.id);
    }
  }

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
    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError('PDF must be smaller than 5 MB.');
    }
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
  Future<Uint8List> downloadResult(TestResult result) async =>
      result.bytes ?? (throw StateError('Document unavailable.'));
}
