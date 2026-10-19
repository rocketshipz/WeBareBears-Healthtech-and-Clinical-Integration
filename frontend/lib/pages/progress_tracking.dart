import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme.dart';
import 'notifications_page.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../admin/admin_models.dart';
import '../admin/visit_codec.dart';
import '../admin/patient_profile_card.dart';

class ProgressTrackingPage extends StatefulWidget {
  const ProgressTrackingPage({super.key});
  @override
  State<ProgressTrackingPage> createState() => _ProgressTrackingPageState();
}

class _ProgressTrackingPageState extends State<ProgressTrackingPage> {
  Timer? timer;
  bool loading = false;
  String? error;
  String? selectedId;
  List<Map<String, dynamic>> visits = [];
  bool showingFamily = false;
  bool viewingFamily = false;

  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 5), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (loading) return;
    final token = AuthService.token;
    final familyRequest = showingFamily || viewingFamily;
    if (token == null) {
      if (mounted) {
        setState(() {
          visits = [];
          error = 'Please log in to view your progress.';
        });
      }
      return;
    }
    setState(() => loading = true);
    try {
      final response = await http
          .get(
            Uri.parse(
              '${ApiService.baseUrl}/progress/${familyRequest ? 'family' : 'visits'}',
            ),
            headers: ApiService.defaultHeaders,
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw Exception('Could not load progress. Please try again.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted ||
          token != AuthService.token ||
          familyRequest != (showingFamily || viewingFamily)) {
        return;
      }
      setState(() {
        visits = [
          for (final visit in data['visits']) Map<String, dynamic>.from(visit),
        ];
        if (!visits.any((v) => v['id'] == selectedId)) {
          selectedId = visits.isEmpty ? null : visits.first['id'];
        }
        error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Could not refresh progress. Check your connection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<String, dynamic>? get rawVisit =>
      visits.where((v) => v['id'] == selectedId).firstOrNull;
  Visit? get currentVisit => rawVisit == null ? null : decodeVisit(rawVisit!);
  String get selectedPatientName =>
      viewingFamily ? currentVisit?.name ?? 'Patient' : 'You';
  String get selectedRelationship =>
      viewingFamily ? 'Family progress' : 'Progress';
  String get selectedDepartment => currentVisit?.department ?? '';
  String get selectedQueue => currentVisit?.queueNo ?? '';
  String get selectedStatus => currentVisit?.statusText ?? '';

  void _showMyProgress() {
    if (loading) return;
    setState(() {
      showingFamily = false;
      viewingFamily = false;
      visits = [];
      selectedId = null;
    });
    load();
  }

  void _showFamily() {
    if (loading) return;
    setState(() {
      showingFamily = true;
      viewingFamily = false;
      visits = [];
      selectedId = null;
    });
    load();
  }

  void _openFamilyProgress({
    required String name,
    required String relationship,
    required String department,
    required String queue,
    required String status,
  }) {
    setState(() {
      selectedId = visits.firstWhere((v) => v['queue_no'] == queue)['id'];
      showingFamily = false;
      viewingFamily = true;
    });
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: GradientBackground(
        child: SafeArea(
          bottom: false,

          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),

            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),

            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    FadeSlideIn(index: 0, child: _buildHeader()),

                    const SizedBox(height: 28),

                    FadeSlideIn(index: 1, child: _buildTitle()),

                    const SizedBox(height: 22),

                    FadeSlideIn(index: 2, child: _buildToggle()),

                    const SizedBox(height: 24),

                    if (loading && visits.isEmpty)
                      const Center(child: CircularProgressIndicator()),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: AppColors.red),
                        ),
                      ),
                    if (!loading &&
                        visits.isEmpty &&
                        !showingFamily &&
                        error == null)
                      Text(
                        'Your progress will appear here once hospital staff check you in.',
                        style: AppText.body,
                      ),
                    if (showingFamily)
                      FadeSlideIn(index: 3, child: _buildFamilySection())
                    else if (currentVisit != null) ...[
                      if (visits.length > 1 && !viewingFamily) ...[
                        DropdownButtonFormField<String>(
                          key: ValueKey(selectedId),
                          initialValue: selectedId,
                          decoration: appInputDecoration(
                            hint: 'Select visit',
                            icon: Icons.history,
                          ),
                          isExpanded: true,
                          items: [
                            for (final v in visits)
                              DropdownMenuItem(
                                value: v['id'] as String,
                                child: Text(
                                  '${v['queue_no']} · ${v['hospital']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => selectedId = value),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FadeSlideIn(index: 3, child: _buildPatientCard()),

                      const SizedBox(height: 28),

                      FadeSlideIn(
                        index: 4,
                        child: Text('Visit progress', style: AppText.heading),
                      ),

                      const SizedBox(height: 12),

                      FadeSlideIn(index: 5, child: _buildProgressTimeline()),

                      if (rawVisit?['diagnosis'] != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: cardDecoration(radius: 22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Diagnosis and treatment',
                                style: AppText.heading,
                              ),
                              for (final entry in {
                                'diagnosis': 'Diagnosis',
                                'treatment_notes': 'Treatment',
                                'medications': 'Medications',
                                'follow_up_instructions': 'Follow-up',
                              }.entries) ...[
                                const SizedBox(height: 12),
                                Text(entry.value, style: AppText.caption),
                                Text(
                                  PatientProfileCard.format(
                                    rawVisit!['diagnosis'][entry.key],
                                  ),
                                  style: AppText.bodyStrong,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      FadeSlideIn(index: 6, child: _buildAccessInfo()),

                      const SizedBox(height: 18),

                      FadeSlideIn(index: 7, child: _buildDisclaimer()),
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: BrandWordmark(size: 32),
          ),
        ),

        IconButton(
          onPressed: loading ? null : load,
          tooltip: 'Refresh progress',
          icon: const Icon(Icons.refresh_rounded),
        ),
        Pressable(
          onTap: _openNotifications,

          child: Container(
            width: 42,
            height: 42,

            decoration: cardDecoration(radius: 14),

            child: Stack(
              clipBehavior: Clip.none,

              children: [
                const Center(
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.textDark,
                    size: 20,
                  ),
                ),

                Positioned(
                  right: 10,
                  top: 9,

                  child: Container(
                    width: 9,
                    height: 9,

                    decoration: BoxDecoration(
                      color: AppColors.red,
                      shape: BoxShape.circle,

                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TITLE
  // ============================================================

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text('Progress Tracking', style: AppText.display),

        const SizedBox(height: 8),

        Text(
          'Follow hospital visit updates for you and approved family members.',
          style: AppText.body,
        ),
      ],
    );
  }

  // ============================================================
  // MY PROGRESS / FAMILY
  // ============================================================

  Widget _buildToggle() {
    return Container(
      padding: const EdgeInsets.all(4),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: AppColors.border),
      ),

      child: Row(
        children: [
          Expanded(
            child: _toggleButton(
              label: 'Progress',
              icon: Icons.person_outline_rounded,
              selected: !showingFamily,
              onTap: _showMyProgress,
            ),
          ),

          const SizedBox(width: 4),

          Expanded(
            child: _toggleButton(
              label: 'Family',
              icon: Icons.family_restroom_rounded,
              selected: showingFamily,
              onTap: _showFamily,
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        height: 46,

        decoration: BoxDecoration(
          color: selected ? AppColors.darkTeal : Colors.transparent,

          borderRadius: BorderRadius.circular(13),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 18,

              color: selected ? Colors.white : AppColors.grey,
            ),

            const SizedBox(width: 7),

            Text(
              label,

              style: AppText.style(
                13,
                FontWeight.w700,
                selected ? Colors.white : AppColors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CURRENT PATIENT
  // ============================================================

  Widget _buildPatientCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: cardDecoration(radius: 22),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,

                decoration: BoxDecoration(
                  color: AppColors.paleTeal,

                  borderRadius: BorderRadius.circular(15),
                ),

                child: const Icon(
                  Icons.person_rounded,
                  color: AppColors.teal,
                  size: 25,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(selectedPatientName, style: AppText.heading),

                    const SizedBox(height: 2),

                    Text(selectedRelationship, style: AppText.caption),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EF),

                  borderRadius: BorderRadius.circular(30),
                ),

                child: Text(
                  currentVisit!.isComplete ? 'Completed visit' : 'Active visit',

                  style: AppText.style(
                    11,
                    FontWeight.w700,
                    const Color(0xFF287749),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(14),

            decoration: BoxDecoration(
              color: AppColors.paleTeal,

              borderRadius: BorderRadius.circular(16),
            ),

            child: Column(
              children: [
                _summaryRow(
                  icon: Icons.local_hospital_outlined,
                  label: 'Hospital',
                  value: currentVisit!.hospital,
                ),
                const SizedBox(height: 12),
                _summaryRow(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Queue number',
                  value: selectedQueue,
                ),

                const SizedBox(height: 12),

                _summaryRow(
                  icon: Icons.local_hospital_outlined,
                  label: 'Department',
                  value: selectedDepartment,
                ),

                const SizedBox(height: 12),

                _summaryRow(
                  icon: Icons.schedule_rounded,
                  label: 'Current status',
                  value: selectedStatus,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.teal),

        const SizedBox(width: 9),

        Expanded(child: Text(label, style: AppText.caption)),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppText.bodyStrong,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FAMILY SECTION
  // ============================================================

  Widget _buildFamilySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Family progress', style: AppText.heading),
      const SizedBox(height: 12),
      if (!loading && visits.isEmpty)
        Text('No shared family visits', style: AppText.body),
      for (final data in visits) ...[
        _familyCard(
          name: decodeVisit(data).name,
          relationship: 'Emergency contact',
          initials: decodeVisit(data).name.isEmpty
              ? '?'
              : decodeVisit(data).name.substring(0, 1),
          status: decodeVisit(data).isComplete ? 'Completed' : 'Active visit',
          currentStage: decodeVisit(data).statusText,
          department: decodeVisit(data).department,
          queue: decodeVisit(data).queueNo,
          active: true,
        ),
        const SizedBox(height: 12),
      ],
      _buildFamilyNote(),
    ],
  );

  Widget _familyCard({
    required String name,
    required String relationship,
    required String initials,
    required String status,
    required String currentStage,
    required String department,
    required String queue,
    required bool active,
  }) {
    return Pressable(
      onTap: () {
        if (active) {
          _openFamilyProgress(
            name: name,
            relationship: relationship,
            department: department,
            queue: queue,
            status: currentStage,
          );
        }
      },

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(16),

        decoration: cardDecoration(radius: 20),

        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,

              alignment: Alignment.center,

              decoration: BoxDecoration(
                color: active ? AppColors.paleTeal : AppColors.background,

                borderRadius: BorderRadius.circular(15),
              ),

              child: Text(
                initials,

                style: AppText.style(
                  15,
                  FontWeight.w700,
                  active ? AppColors.darkTeal : AppColors.grey,
                ),
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(child: Text(name, style: AppText.bodyStrong)),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),

                        decoration: BoxDecoration(
                          color: active
                              ? const Color(0xFFEAF7EF)
                              : const Color(0xFFF1F4F4),

                          borderRadius: BorderRadius.circular(20),
                        ),

                        child: Text(
                          status,

                          style: AppText.style(
                            10,
                            FontWeight.w600,
                            active ? const Color(0xFF287749) : AppColors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(relationship, style: AppText.caption),

                  const SizedBox(height: 8),

                  Text(
                    currentStage,

                    style: AppText.style(
                      12,
                      FontWeight.w600,
                      active ? AppColors.darkTeal : AppColors.grey,
                    ),
                  ),

                  if (active) ...[
                    const SizedBox(height: 2),

                    Text(department, style: AppText.caption),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            if (active)
              const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.grey,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyNote() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),

        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(Icons.shield_outlined, color: AppColors.teal, size: 22),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Family progress is only available when the patient has approved access.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROGRESS TIMELINE
  // ============================================================

  Widget _buildProgressTimeline() {
    final steps = currentVisit!.steps;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 6),
      decoration: cardDecoration(radius: 22),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _progressStep(
              title: steps[i].name,
              time: steps[i].completedAt == null && steps[i].startedAt == null
                  ? '-'
                  : PatientProfileCard.timestamp(
                      (steps[i].completedAt ?? steps[i].startedAt)!
                          .toUtc()
                          .toIso8601String(),
                    ),
              status: switch (steps[i].status) {
                StepStatus.done => 'Done',
                StepStatus.inProgress => 'In progress',
                StepStatus.waiting => 'Waiting',
              },
              state: switch (steps[i].status) {
                StepStatus.done => VisitProgressState.completed,
                StepStatus.inProgress => VisitProgressState.current,
                StepStatus.waiting => VisitProgressState.pending,
              },
              showLine: i < steps.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _progressStep({
    required String title,
    required String time,
    required String status,
    required VisitProgressState state,
    required bool showLine,
  }) {
    final bool completed = state == VisitProgressState.completed;

    final bool current = state == VisitProgressState.current;

    Color markerColor;
    Color badgeBackground;
    Color badgeText;

    if (completed) {
      markerColor = const Color(0xFF3BA96B);

      badgeBackground = const Color(0xFFEAF7EF);

      badgeText = const Color(0xFF287749);
    } else if (current) {
      markerColor = AppColors.darkTeal;

      badgeBackground = AppColors.paleTeal;

      badgeText = AppColors.darkTeal;
    } else {
      markerColor = const Color(0xFFBBC7C7);

      badgeBackground = const Color(0xFFF1F4F4);

      badgeText = AppColors.grey;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 36,

            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,

                  decoration: BoxDecoration(
                    color: completed ? markerColor : Colors.white,

                    shape: BoxShape.circle,

                    border: Border.all(color: markerColor, width: 2),
                  ),

                  child: completed
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : current
                      ? Center(
                          child: Container(
                            width: 13,
                            height: 13,

                            decoration: const BoxDecoration(
                              color: AppColors.darkTeal,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),

                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,

                      margin: const EdgeInsets.symmetric(vertical: 3),

                      color: completed
                          ? const Color(0xFF9BD8B5)
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Expanded(
                        child: Text(
                          title,

                          style: current
                              ? AppText.style(
                                  14,
                                  FontWeight.w700,
                                  AppColors.darkTeal,
                                )
                              : AppText.bodyStrong,
                        ),
                      ),

                      const SizedBox(width: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),

                        decoration: BoxDecoration(
                          color: badgeBackground,

                          borderRadius: BorderRadius.circular(30),
                        ),

                        child: Text(
                          status,

                          style: AppText.style(10, FontWeight.w600, badgeText),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(time, style: AppText.caption),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACCESS INFO
  // ============================================================

  Widget _buildAccessInfo() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: cardDecoration(radius: 20),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: AppColors.paleTeal,

              borderRadius: BorderRadius.circular(14),
            ),

            child: const Icon(
              Icons.family_restroom_rounded,
              color: AppColors.teal,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text('Family visibility', style: AppText.bodyStrong),

                const SizedBox(height: 3),

                Text(
                  'Only family members you accept in Profile can view progress. Revoke access there anytime.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISCLAIMER
  // ============================================================

  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.70),

        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.teal,
            size: 21,
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              'Progress reflects the latest status recorded by the hospital. '
              'Actual timing may change depending on clinical priority and hospital workflow.',
              style: AppText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// PROGRESS STATES
// ============================================================

enum VisitProgressState { completed, current, pending }
