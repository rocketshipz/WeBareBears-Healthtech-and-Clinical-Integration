import 'dart:async';
import 'package:flutter/foundation.dart';

import 'admin_models.dart';
import 'admin_repository.dart';

// Screens import this file only; it re-exports the models.
export 'admin_models.dart';

/// State shared by every hospital screen.
/// Changes are applied immediately on screen, then saved through [AdminRepository].
class AdminStore extends ChangeNotifier {
  AdminRepository _repo = DemoAdminRepository();

  AdminRepository get repo => _repo;

  StaffMember? staff;
  final List<Visit> visits = [];
  final List<IncomingPatient> incoming = [];

  /// Set when a save / refresh fails; the shell shows it as a message.
  final ValueNotifier<String?> syncError = ValueNotifier<String?>(null);

  void Function()? _stopListening;
  Timer? _debounce;

  AdminStore() {
    _seed();
  }

  /// Called once at start-up (see main_admin.dart).
  void useRepository(AdminRepository repo) {
    _repo = repo;
    visits.clear();
    incoming.clear();

    if (repo.isDemo) _seed();

    notifyListeners();
  }

  // ------------------------------------------------------------
  // AUTH
  // ------------------------------------------------------------

  Future<void> signIn(
    String staffId,
    String password, {
    String? hospital,
    String? role,
  }) async {
    staff = await _repo.signIn(
      staffId,
      password,
      hospital: hospital,
      role: role,
    );
    notifyListeners();

    await refresh();

    _stopListening?.call();
    _stopListening = _repo.listen(staff!.hospital, _scheduleRefresh);
  }

  Future<void> signOut() async {
    _stopListening?.call();
    _stopListening = null;

    try {
      await _repo.signOut();
    } catch (_) {}

    staff = null;

    if (!_repo.isDemo) {
      visits.clear();
      incoming.clear();
    }

    notifyListeners();
  }

  // ------------------------------------------------------------
  // LOADING
  // ------------------------------------------------------------

  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), refresh);
  }

  Future<void> refresh() async {
    final s = staff;
    if (s == null) return;

    try {
      if (!_repo.isDemo) {
        _merge(await _repo.loadVisits(s.hospital));
      }

      final inc = await _repo.loadIncoming(s.hospital);
      incoming
        ..clear()
        ..addAll(inc);

      syncError.value = null;
    } catch (_) {
      syncError.value = 'Could not sync with the server.';
    }

    notifyListeners();
  }

  /// Updates visits in place so open screens keep working.
  void _merge(List<Visit> fresh) {
    final byId = {for (final v in visits) v.id: v};
    final merged = <Visit>[];

    for (final f in fresh) {
      final existing = byId[f.id];

      if (existing != null) {
        existing.updateFrom(f);
        merged.add(existing);
      } else {
        merged.add(f);
      }
    }

    visits
      ..clear()
      ..addAll(merged);
  }

  // ------------------------------------------------------------
  // QUERIES
  // ------------------------------------------------------------

  List<Visit> get active => visits.where((v) => !v.isComplete).toList();

  List<Visit> get completed => visits.where((v) => v.isComplete).toList();

  String get _staffId => staff?.id ?? 'N/A';

  String get _staffName => staff?.name ?? 'Staff';

  // ------------------------------------------------------------
  // CREATE VISITS
  // ------------------------------------------------------------

  /// Walk-in patient typed in by staff.
  Future<Visit> registerPatient({
    required String name,
    required String ic,
    required int age,
    required String sex,
    required String complaint,
    required Acuity acuity,
    required List<String> tests,
    required String patientPhone,
  }) async {
    final queueNo = await _repo.nextQueueNo(staff?.hospital ?? '');

    return _createVisit(
      queueNo: queueNo,
      name: name,
      ic: ic,
      age: age,
      sex: sex,
      complaint: complaint,
      acuity: acuity,
      tests: tests,
      patientPhone: patientPhone,
    );
  }

  /// A patient from the app who has now arrived: details and triage come from
  /// the database, so nothing is typed again.
  Future<Visit> checkIn(
    IncomingPatient p, {
    List<String> tests = const [],
  }) async {
    final queueNo = await _repo.nextQueueNo(staff?.hospital ?? '');

    final visit = _createVisit(
      queueNo: queueNo,
      name: p.name,
      ic: p.ic,
      age: p.age,
      sex: p.sex,
      complaint: '${p.triage.symptom} · ${p.triage.severity.toLowerCase()}',
      acuity: p.triage.acuity,
      tests: tests,
      patientPhone: p.phone,
      patientId: p.patientId,
      triageReportId: p.reportId,
      triage: p.triage,
      bloodType: p.bloodType,
      allergies: p.allergies,
      conditions: p.conditions,
      medication: p.medication,
    );

    incoming.removeWhere((i) => i.reportId == p.reportId);
    notifyListeners();

    return visit;
  }

  Visit _createVisit({
    required String queueNo,
    required String name,
    required String ic,
    required int age,
    required String sex,
    required String complaint,
    required Acuity acuity,
    required List<String> tests,
    required String patientPhone,
    String? patientId,
    String? triageReportId,
    TriageSummary? triage,
    String bloodType = '',
    String allergies = '',
    String conditions = '',
    String medication = '',
  }) {
    final now = DateTime.now();

    final visit = Visit(
      queueNo: queueNo,
      name: name,
      ic: ic,
      age: age,
      sex: sex,
      complaint: complaint,
      acuity: acuity,
      department: staff?.department ?? 'Emergency Department',
      hospital: staff?.hospital ?? '',
      arrivedAt: now,
      steps: _buildSteps(tests),
      patientPhone: patientPhone,
      patientId: patientId,
      triageReportId: triageReportId,
      triage: triage,
      bloodType: bloodType,
      allergies: allergies,
      conditions: conditions,
      medication: medication,
    );

    // Registration is done the moment the patient is entered.
    _apply(visit, visit.steps.first, StepStatus.done, now);

    visits.insert(0, visit);
    notifyListeners();

    _persist(visit, newLogs: List.of(visit.log));

    return visit;
  }

  // ------------------------------------------------------------
  // PROGRESS
  // ------------------------------------------------------------

  /// waiting -> in progress -> done for the current stage.
  void advance(Visit v, {String? outcome}) {
    final step = v.currentStep;
    if (step == null) return;

    final now = DateTime.now();

    final entry = step.status == StepStatus.waiting
        ? _apply(v, step, StepStatus.inProgress, now)
        : _apply(v, step, StepStatus.done, now);

    if (v.isComplete) {
      v.completedAt = now;
      if (outcome != null) v.outcome = outcome;
    }

    notifyListeners();
    _persist(v, newLogs: [entry]);
  }

  /// Reverts the latest stage change. The original entry is kept (marked
  /// undone) and a new "Undid ..." entry is added, so the audit trail stays whole.
  void undo(Visit v) {
    final target = v.lastUndoable;
    if (target == null) return;

    final step = v.steps.firstWhere((s) => s.id == target.stepId);

    step.status = target.from!;

    if (target.from == StepStatus.waiting) {
      step.startedAt = null;
      step.completedAt = null;
    } else if (target.from == StepStatus.inProgress) {
      step.completedAt = null;
    }

    target.undone = true;
    v.outcome = null;
    v.completedAt = null;

    final record = LogEntry(
      text: 'Undid: ${target.text}',
      staffId: _staffId,
      staffName: _staffName,
      time: DateTime.now(),
      isUndoRecord: true,
    );

    v.log.add(record);

    notifyListeners();
    _persist(v, newLogs: [record], updatedLogs: [target]);
  }

  void setAcuity(Visit v, Acuity a) {
    if (v.acuity == a) return;

    v.acuity = a;

    final entry = _entry('Triage zone set to ${a.labelEn} (${a.descriptionEn})');
    v.log.add(entry);

    notifyListeners();
    _persist(v, newLogs: [entry]);
  }

  void addTest(Visit v, String test) {
    final step = VisitStep.test(test);
    if (v.steps.any((s) => s.id == step.id)) return;

    // tests go just before "Doctor consultation"
    final doctorIndex = v.steps.indexWhere((s) => s.id == 'doctor');
    v.steps.insert(doctorIndex < 0 ? v.steps.length : doctorIndex, step);

    final entry = _entry('$test added to the visit');
    v.log.add(entry);

    notifyListeners();
    _persist(v, newLogs: [entry]);
  }

  void removeStep(Visit v, VisitStep step) {
    if (!step.isTest || step.status != StepStatus.waiting) return;

    v.steps.remove(step);

    final entry = _entry('${step.name} removed from the visit');
    v.log.add(entry);

    notifyListeners();

    _repo.deleteStep(v, step).then(
      (_) => _persist(v, newLogs: [entry]),
      onError: (_) => _fail('Could not remove the test.'),
    );
  }

  /// Renames a test. Core stages keep their names because the patient app
  /// shows the same wording.
  void renameStep(Visit v, VisitStep step, String name) {
    final trimmed = name.trim();
    if (!step.isTest || trimmed.isEmpty || trimmed == step.name) return;

    final entry = _entry('${step.name} renamed to $trimmed');
    step.name = trimmed;
    v.log.add(entry);

    notifyListeners();
    _persist(v, newLogs: [entry]);
  }

  /// Sets a stage straight to [to], e.g. to correct a mistake or to record a
  /// test that was done out of order. Logged and undoable like [advance].
  void setStepStatus(Visit v, VisitStep step, StepStatus to) {
    if (step.status == to) return;

    final now = DateTime.now();
    final entry = _apply(v, step, to, now);

    if (v.isComplete) {
      v.completedAt ??= now;
    } else {
      v.completedAt = null;
      v.outcome = null;
    }

    notifyListeners();
    _persist(v, newLogs: [entry]);
  }

  /// Moves the test at [oldIndex] so it ends up at [newIndex], both counted
  /// among the tests only (same as [ReorderableListView.onReorderItem]).
  /// Completed tests never move: only the unfinished tests are reordered,
  /// among the places they already take. Tests always stay between triage
  /// and the doctor consultation.
  void reorderTests(Visit v, int oldIndex, int newIndex) {
    final tests = v.steps.where((s) => s.isTest).toList();

    if (oldIndex < 0 ||
        oldIndex >= tests.length ||
        newIndex < 0 ||
        newIndex >= tests.length ||
        tests[oldIndex].status == StepStatus.done) {
      return;
    }

    final step = tests[oldIndex];

    // order the unfinished tests as dropped, then put them back in their slots
    final dropped = List.of(tests)
      ..removeAt(oldIndex)
      ..insert(newIndex, step);
    final pending = dropped.where((s) => s.status != StepStatus.done).toList();

    var next = 0;
    final result = [
      for (final t in tests) t.status == StepStatus.done ? t : pending[next++],
    ];

    var changed = false;
    for (var i = 0; i < tests.length; i++) {
      if (result[i] != tests[i]) changed = true;
    }
    if (!changed) return;

    final first = v.steps.indexWhere((s) => s.isTest);
    v.steps
      ..removeWhere((s) => s.isTest)
      ..insertAll(first, result);

    final at = pending.indexOf(step);
    final entry = _entry(
      at < pending.length - 1
          ? '${step.name} moved before ${pending[at + 1].name}'
          : '${step.name} moved after ${pending[at - 1].name}',
    );
    v.log.add(entry);

    notifyListeners();
    _persist(v, newLogs: [entry]);
  }

  void setNote(Visit v, VisitStep step, String note) {
    step.note = note.trim();

    notifyListeners();
    _persist(v);
  }

  // ------------------------------------------------------------
  // TEST RESULT DOCUMENTS
  // ------------------------------------------------------------

  /// Uploads a scanned result (already a PDF) and attaches it to the test.
  /// Throws if the upload fails, so the scan screen can offer a retry.
  Future<TestResult> addResult(
    Visit v,
    VisitStep step,
    Uint8List pdfBytes,
    int pages,
  ) async {
    final s = staff;

    if (s == null) throw StateError('Not signed in');

    final fileName = '${step.name} result - ${v.queueNo}.pdf';

    final result = await _repo.uploadResult(
      visit: v,
      step: step,
      bytes: pdfBytes,
      fileName: fileName,
      pages: pages,
      staff: s,
    );

    step.results.add(result);

    final entry = _entry(
      '${step.name} result uploaded ($pages ${pages == 1 ? 'page' : 'pages'})',
    );
    v.log.add(entry);

    notifyListeners();
    _persist(v, newLogs: [entry]);

    return result;
  }

  Future<Uint8List> loadResultBytes(TestResult r) async {
    return r.bytes ?? await _repo.downloadResult(r);
  }

  // ------------------------------------------------------------
  // FAMILY LINK
  // ------------------------------------------------------------

  void setFamilySharing(Visit v, bool on) {
    v.familySharing = on;

    final entry = _entry(
      on ? 'Progress tracking link enabled' : 'Progress tracking link disabled',
    );
    v.log.add(entry);

    notifyListeners();
    _persist(v, newLogs: [entry]);
  }

  /// Old link stops working immediately; a fresh one is created.
  void regenerateShareLink(Visit v) {
    v.shareToken = newShareToken();

    final entry = _entry('Progress tracking link replaced (old link revoked)');
    v.log.add(entry);

    notifyListeners();
    _persist(v, newLogs: [entry]);
  }

  // ------------------------------------------------------------
  // INTERNALS
  // ------------------------------------------------------------

  LogEntry _entry(String text) {
    return LogEntry(
      text: text,
      staffId: _staffId,
      staffName: _staffName,
      time: DateTime.now(),
    );
  }

  void _fail(String message) {
    syncError.value = message;
  }

  void _persist(
    Visit v, {
    List<LogEntry> newLogs = const [],
    List<LogEntry> updatedLogs = const [],
  }) {
    _repo
        .saveVisit(v, newLogs: newLogs, updatedLogs: updatedLogs)
        .then(
          (_) => syncError.value = null,
          onError: (_) =>
              _fail('Could not save the last update. Check your connection.'),
        );
  }

  List<VisitStep> _buildSteps(List<String> tests) {
    return [
      VisitStep.registration(),
      VisitStep.triage(),
      ...tests.map(VisitStep.test),
      VisitStep.doctor(),
      VisitStep.discharge(),
    ];
  }

  LogEntry _apply(
    Visit v,
    VisitStep s,
    StepStatus to,
    DateTime at, {
    String? staffId,
  }) {
    final from = s.status;
    s.status = to;

    if (to == StepStatus.inProgress) {
      s.startedAt = at;
    } else if (to == StepStatus.done) {
      s.completedAt = at;
      s.startedAt ??= at;
    }

    final id = staffId ?? _staffId;

    final entry = LogEntry(
      text: switch (to) {
        StepStatus.inProgress => '${s.name} started',
        StepStatus.done => '${s.name} completed',
        StepStatus.waiting => '${s.name} set back to waiting',
      },
      staffId: id,
      staffName: staffId == null
          ? _staffName
          : (demoStaffNames[staffId] ?? 'Staff $staffId'),
      time: at,
      stepId: s.id,
      from: from,
      to: to,
    );

    v.log.add(entry);
    return entry;
  }

  // ------------------------------------------------------------
  // SAMPLE DATA (demo mode only)
  // ------------------------------------------------------------

  void _seed() {
    final now = DateTime.now();
    DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));

    Visit make({
      required String queueNo,
      required String name,
      required String ic,
      required int age,
      required String sex,
      required String complaint,
      required Acuity acuity,
      required List<String> tests,
      required int arrivedMinAgo,
      String allergies = '',
      String conditions = '',
      String bloodType = '',
      TriageSummary? triage,
      bool sharing = false,
    }) {
      return Visit(
        queueNo: queueNo,
        name: name,
        ic: ic,
        age: age,
        sex: sex,
        complaint: complaint,
        acuity: acuity,
        department: 'Emergency Department',
        hospital: 'Central General Hospital',
        arrivedAt: ago(arrivedMinAgo),
        steps: _buildSteps(tests),
        allergies: allergies,
        conditions: conditions,
        bloodType: bloodType,
        triage: triage,
        familySharing: sharing,
        patientPhone: '0123456789',
      );
    }

    VisitStep step(Visit v, String id) => v.steps.firstWhere((s) => s.id == id);

    // A128: matches the patient-side draft (waiting on X-ray)
    final a128 = make(
      queueNo: 'A128',
      name: 'Aisyah Binti Ahmad',
      ic: '000101-00-0000',
      age: 24,
      sex: 'Female',
      complaint: 'Wheezing and shortness of breath',
      acuity: Acuity.yellow,
      tests: ['Blood test', 'X-ray'],
      arrivedMinAgo: 90,
      allergies: 'Penicillin',
      conditions: 'Asthma',
      bloodType: 'O+',
      sharing: true,
      triage: TriageSummary(
        symptom: 'Cough',
        severity: 'Moderate',
        duration: '1–3 days',
        dangerSigns: const [],
        level: 3,
        submittedAt: ago(96),
      ),
    );
    _apply(a128, step(a128, 'registration'), StepStatus.done, ago(88),
        staffId: 'N-1021');
    _apply(a128, step(a128, 'triage'), StepStatus.inProgress, ago(80),
        staffId: 'N-1021');
    _apply(a128, step(a128, 'triage'), StepStatus.done, ago(70),
        staffId: 'N-1021');
    _apply(a128, step(a128, 'blood_test'), StepStatus.inProgress, ago(50),
        staffId: 'N-1034');
    _apply(a128, step(a128, 'blood_test'), StepStatus.done, ago(25),
        staffId: 'N-1034');
    _apply(a128, step(a128, 'x-ray'), StepStatus.inProgress, ago(8),
        staffId: 'N-1034');

    // A127: red zone, with the doctor now
    final a127 = make(
      queueNo: 'A127',
      name: 'Rahman Bin Yusof',
      ic: '780512-14-5531',
      age: 47,
      sex: 'Male',
      complaint: 'Chest pain',
      acuity: Acuity.red,
      tests: ['ECG', 'Blood test'],
      arrivedMinAgo: 55,
      conditions: 'Hypertension',
      bloodType: 'A+',
      triage: TriageSummary(
        symptom: 'Other',
        severity: 'Severe',
        duration: 'Less than 24 hours',
        dangerSigns: const ['Chest pain'],
        level: 1,
        submittedAt: ago(62),
      ),
    );
    _apply(a127, step(a127, 'registration'), StepStatus.done, ago(54),
        staffId: 'N-1021');
    _apply(a127, step(a127, 'triage'), StepStatus.done, ago(50),
        staffId: 'N-1021');
    _apply(a127, step(a127, 'ecg'), StepStatus.done, ago(40),
        staffId: 'N-1034');
    _apply(a127, step(a127, 'blood_test'), StepStatus.done, ago(22),
        staffId: 'N-1034');
    _apply(a127, step(a127, 'doctor'), StepStatus.inProgress, ago(12),
        staffId: 'D-2001');

    // A129: just arrived, being triaged
    final a129 = make(
      queueNo: 'A129',
      name: 'Nurul Huda',
      ic: '020830-10-1122',
      age: 22,
      sex: 'Female',
      complaint: 'Sprained ankle',
      acuity: Acuity.green,
      tests: ['X-ray'],
      arrivedMinAgo: 14,
      bloodType: 'B+',
      triage: TriageSummary(
        symptom: 'Minor injury',
        severity: 'Mild',
        duration: 'Less than 24 hours',
        dangerSigns: const [],
        level: 4,
        submittedAt: ago(20),
      ),
    );
    _apply(a129, step(a129, 'registration'), StepStatus.done, ago(13),
        staffId: 'N-1021');
    _apply(a129, step(a129, 'triage'), StepStatus.inProgress, ago(4),
        staffId: 'N-1021');

    // A126: walk-in, finished earlier
    final a126 = make(
      queueNo: 'A126',
      name: 'Lim Wei Jie',
      ic: '950304-07-6678',
      age: 31,
      sex: 'Male',
      complaint: 'Fever for 3 days',
      acuity: Acuity.green,
      tests: ['Blood test'],
      arrivedMinAgo: 150,
    );
    _apply(a126, step(a126, 'registration'), StepStatus.done, ago(148),
        staffId: 'N-1021');
    _apply(a126, step(a126, 'triage'), StepStatus.done, ago(140),
        staffId: 'N-1021');
    _apply(a126, step(a126, 'blood_test'), StepStatus.done, ago(110),
        staffId: 'N-1034');
    _apply(a126, step(a126, 'doctor'), StepStatus.done, ago(70),
        staffId: 'D-2001');
    _apply(a126, step(a126, 'discharge'), StepStatus.done, ago(60),
        staffId: 'N-1021');
    a126.outcome = 'Discharged home';
    a126.completedAt = ago(60);

    visits.addAll([a129, a128, a127, a126]);
  }
}

/// Single shared instance used by every staff screen.
final AdminStore adminStore = AdminStore();