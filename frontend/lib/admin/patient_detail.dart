import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import 'scan_result.dart';
import 'patient_profile_card.dart';
import 'diagnosis_card.dart';
import 'sync_banner.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';
import 'admin_i18n.dart';

/// Where nurses log a patient's progress, one stage at a time.
/// Mirrors the timeline patients and families see in the app.
class PatientDetailPage extends StatefulWidget {
  final Visit visit;

  const PatientDetailPage({super.key, required this.visit});

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  Visit get visit => widget.visit;
  bool showProfile = false;
  final scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void selectSection(bool profile) {
    FocusScope.of(context).unfocus();
    setState(() => showProfile = profile);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && scrollController.hasClients) {
        scrollController.jumpTo(0);
      }
    });
  }

  bool get consultationComplete => visit.steps.any(
    (step) => step.id == 'doctor' && step.status == StepStatus.done,
  );

  // ------------------------------------------------------------
  // ACTIONS
  // ------------------------------------------------------------

  Future<void> _advance(BuildContext context) async {
    final step = visit.currentStep;
    if (step == null) return;

    final isLast = step.id == 'discharge';
    final finishing = isLast && step.status == StepStatus.inProgress;

    if (finishing) {
      final outcome = await showStaffSheet<String>(
        context,
        builder: (sheetContext) => _OutcomeSheet(),
      );

      if (outcome == null) return;

      adminStore.advance(visit, outcome: outcome);

      if (context.mounted) {
        showAppSnack(
          context,
          tr('Visit completed: {outcome}.', {'outcome': trText(outcome)}),
        );
      }
      return;
    }

    adminStore.advance(visit);

    if (context.mounted) {
      final updated = visit.steps.firstWhere(
        (s) => s.id == step.id,
        orElse: () => step,
      );
      showAppSnack(context, '${updated.title}.');
    }
  }

  void _changeZone(BuildContext context) {
    showStaffSheet<void>(
      context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Triage zone'), style: AppText.heading),
          const SizedBox(height: 4),
          Text(tr('Update after nurse assessment.'), style: AppText.caption),
          const SizedBox(height: 16),
          for (final a in Acuity.values)
            SheetOption(
              icon: Icons.circle,
              color: a.color,
              title: tr('{zone} zone', {'zone': a.label}),
              subtitle: a.description,
              selected: visit.acuity == a,
              onTap: () {
                adminStore.setAcuity(visit, a);
                Navigator.pop(sheetContext);
              },
            ),
        ],
      ),
    );
  }

  void _addTest(BuildContext context) {
    final available = VisitStep.testCatalog.keys
        .where((t) => !visit.steps.any((s) => s.id == VisitStep.slug(t)))
        .toList();

    showStaffSheet<void>(
      context,
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CustomTestInput(visit: visit),
          const SizedBox(height: 16),
          Text(tr('Add a test'), style: AppText.heading),
          const SizedBox(height: 4),
          Text(
            tr('It is added before the doctor consultation.'),
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          if (available.isEmpty)
            Text(
              tr('All available tests are already added.'),
              style: AppText.body,
            )
          else
            for (final t in available)
              SheetOption(
                icon: VisitStep.testCatalog[t]!,
                title: tr(t),
                onTap: () {
                  adminStore.addTest(visit, t);
                  Navigator.pop(sheetContext);
                },
              ),
        ],
      ),
    );
  }

  void _editStep(BuildContext context, VisitStep step) {
    showStaffSheet<void>(
      context,
      builder: (sheetContext) => _StepSheet(visit: visit, step: step),
    );
  }

  void _scan(BuildContext context, VisitStep step) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScanResultPage(visit: visit, step: step),
      ),
    );
  }

  /// Opens WhatsApp with the tracking link ready to send to the patient,
  /// who can forward it to family.
  Future<void> _sendWhatsApp(BuildContext context) async {
    final message = tr(
      'Follow the live progress of your hospital visit at {hospital}: {link}\n\n'
      'You can forward this link to your family so they can follow too.',
      {'hospital': visit.hospital, 'link': visit.shareLink},
    );

    var phone = visit.patientPhone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phone.startsWith('0')) phone = '6$phone';

    final uri = Uri.parse(
      phone.isEmpty
          ? 'https://wa.me/?text=${Uri.encodeComponent(message)}'
          : 'https://wa.me/$phone?text=${Uri.encodeComponent(message)}',
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok && context.mounted) {
      showAppSnack(context, tr('Could not open WhatsApp.'));
    }
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: AnimatedBuilder(
            animation: adminStore,
            builder: (context, _) {
              return SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TOP BAR
                        FadeSlideIn(
                          index: 0,
                          child: Row(
                            children: [
                              CircleBackButton(
                                onTap: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 14),
                              const BrandWordmark(),
                              const SizedBox(width: 10),
                              const StaffTag(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),
                        const StaffSyncBanner(),

                        FadeSlideIn(index: 1, child: _header(context)),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<bool>(
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? AppColors.darkTeal
                                    : Colors.white,
                              ),
                              foregroundColor: WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                    ? Colors.white
                                    : AppColors.darkTeal,
                              ),
                            ),
                            segments: const [
                              ButtonSegment(
                                value: false,
                                label: Text('Timeline'),
                                icon: Icon(Icons.timeline_rounded),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text('Profile'),
                                icon: Icon(Icons.person_outline_rounded),
                              ),
                            ],
                            selected: {showProfile},
                            onSelectionChanged: (values) =>
                                selectSection(values.first),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Offstage(
                          offstage: !showProfile,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (visit.profile.isNotEmpty)
                                PatientProfileCard(profile: visit.profile)
                              else
                                Text(
                                  'No saved profile details available.',
                                  style: AppText.body,
                                ),
                              if (visit.triage != null) ...[
                                const SizedBox(height: 16),
                                _triageCard(),
                              ],
                            ],
                          ),
                        ),
                        Offstage(
                          offstage: showProfile,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _actionCard(context),
                              const SizedBox(height: 26),
                              _timeline(context),
                              if (!adminStore.repo.isDemo &&
                                  consultationComplete) ...[
                                const SizedBox(height: 24),
                                DiagnosisCard(
                                  key: ValueKey(visit.id),
                                  visitId: visit.id,
                                ),
                              ],
                              const SizedBox(height: 26),
                              _familyCard(context),
                              const SizedBox(height: 26),
                              _activityLog(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _header(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tr('Queue No.'), style: AppText.caption),
              const Spacer(),
              Text(
                tr('Arrived {time}', {'time': fmtTime(visit.arrivedAt)}),
                style: AppText.caption,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                visit.queueNo,
                style: AppText.style(28, FontWeight.w800, AppColors.textDark),
              ),
              const SizedBox(width: 12),
              Pressable(
                onTap: () => _changeZone(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AcuityPill(acuity: visit.acuity, showDescription: true),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppColors.grey,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(visit.name, style: AppText.heading),
          const SizedBox(height: 2),
          Text(
            [
              tr('{n} yrs', {'n': visit.age}),
              trText(visit.sex),
              if (visit.ic.isNotEmpty) visit.ic,
            ].join('  \u00B7  '),
            style: AppText.caption,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.healing_outlined,
                size: 17,
                color: AppColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(trText(visit.complaint), style: AppText.body),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.local_hospital_outlined,
                size: 17,
                color: AppColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(trText(visit.department), style: AppText.body),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _triageCard() {
    final t = visit.triage!;

    Widget row(String k, String v, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: Text(k, style: AppText.caption)),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: color == null
                  ? AppText.bodyStrong
                  : AppText.style(14, FontWeight.w700, color),
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 18,
                color: AppColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr('Triage report (patient app)'),
                  style: AppText.heading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            tr('Submitted {ago}', {'ago': agoText(t.submittedAt)}),
            style: AppText.caption,
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          row(tr('Outcome'), t.zoneLabel, color: t.acuity.color),
          row(tr('Main symptom'), trText(t.symptom)),
          row(tr('Severity'), trText(t.severity)),
          row(tr('Duration'), trText(t.duration)),
          row(
            tr('Danger signs'),
            t.dangerSigns.isEmpty
                ? tr('None reported')
                : t.dangerSigns.map(trText).join(', '),
            color: t.dangerSigns.isEmpty ? null : AppColors.red,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // CURRENT STAGE + ACTION BUTTON
  // ------------------------------------------------------------

  Widget _actionCard(BuildContext context) {
    final step = visit.currentStep;

    if (step == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.green.withValues(alpha: 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green),
                const SizedBox(width: 8),
                Text(
                  tr('Visit completed'),
                  style: AppText.style(16, FontWeight.w700, AppColors.green),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              visit.outcome == null
                  ? tr('All stages are done.')
                  : trText(visit.outcome!),
              style: AppText.body,
            ),
            if (visit.canUndo) ...[
              const SizedBox(height: 10),
              _undoButton(context),
            ],
          ],
        ),
      );
    }

    final waiting = step.status == StepStatus.waiting;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.paleTeal.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Current stage'), style: AppText.caption),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(step.icon, color: AppColors.darkTeal, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.statusText,
                  style: AppText.style(18, FontWeight.w700, AppColors.darkTeal),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: step.actionLabel,
            icon: waiting ? Icons.play_arrow_rounded : Icons.check_rounded,
            onPressed: () => _advance(context),
          ),
          if (step.isTest && step.status != StepStatus.waiting) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: step.results.isEmpty
                  ? tr('Scan results document')
                  : tr('Scan another document ({n} uploaded)', {
                      'n': step.results.length,
                    }),
              onPressed: () => _scan(context, step),
            ),
          ],
          if (visit.canUndo) ...[
            const SizedBox(height: 6),
            _undoButton(context),
          ],
        ],
      ),
    );
  }

  Widget _undoButton(BuildContext context) {
    final last = visit.lastUndoable!;

    return Pressable(
      onTap: () {
        adminStore.undo(visit);
        showAppSnack(context, tr('Undid: {x}.', {'x': trText(last.text)}));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.undo_rounded, size: 16, color: AppColors.grey),
            const SizedBox(width: 6),
            Text(
              tr('Undo last update ({x})', {'x': trText(last.text)}),
              style: AppText.style(12, FontWeight.w600, AppColors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TIMELINE
  // ------------------------------------------------------------

  Widget _timeline(BuildContext context) {
    final steps = visit.steps;

    // Tests sit together between triage and the doctor; only unfinished
    // tests can be dragged.
    final firstTest = steps.indexWhere((s) => s.isTest);
    final lastTest = steps.lastIndexWhere((s) => s.isTest);
    final before = firstTest < 0 ? steps : steps.sublist(0, firstTest);
    final tests = firstTest < 0
        ? const <VisitStep>[]
        : steps.sublist(firstTest, lastTest + 1);
    final after = firstTest < 0
        ? const <VisitStep>[]
        : steps.sublist(lastTest + 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(tr('Progress timeline'), style: AppText.heading),
            const Spacer(),
            if (!visit.isComplete)
              Pressable(
                onTap: () => _addTest(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: AppColors.darkTeal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        tr('Add test'),
                        style: AppText.style(
                          12,
                          FontWeight.w700,
                          AppColors.darkTeal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr(
            'Tap a stage to edit it. Drag unfinished tests to reorder them. Patients see this timeline live.',
          ),
          style: AppText.caption,
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
          decoration: cardDecoration(radius: 24),
          child: Column(
            children: [
              for (final step in before)
                _timelineRow(context, step, isLast: step == steps.last),
              if (tests.isNotEmpty)
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, _, _) => Material(
                    color: Colors.white,
                    elevation: 6,
                    shadowColor: AppColors.teal.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                    child: child,
                  ),
                  onReorderItem: (from, to) =>
                      adminStore.reorderTests(visit, from, to),
                  children: [
                    for (var i = 0; i < tests.length; i++)
                      // completed tests stay where they are
                      if (tests[i].status == StepStatus.done)
                        KeyedSubtree(
                          key: ValueKey(tests[i].id),
                          child: _timelineRow(
                            context,
                            tests[i],
                            isLast: tests[i] == steps.last,
                          ),
                        )
                      else
                        _dragListener(
                          key: ValueKey(tests[i].id),
                          index: i,
                          child: _timelineRow(
                            context,
                            tests[i],
                            isLast: tests[i] == steps.last,
                            draggable: true,
                          ),
                        ),
                  ],
                ),
              for (final step in after)
                _timelineRow(context, step, isLast: step == steps.last),
            ],
          ),
        ),
      ],
    );
  }

  /// Mouse: drag straight away. Touch: long-press first, so scrolling the
  /// page with a finger doesn't move tests by accident.
  Widget _dragListener({
    required Key key,
    required int index,
    required Widget child,
  }) {
    final touch =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    return touch
        ? ReorderableDelayedDragStartListener(
            key: key,
            index: index,
            child: child,
          )
        : ReorderableDragStartListener(key: key, index: index, child: child);
  }

  Widget _timelineRow(
    BuildContext context,
    VisitStep step, {
    required bool isLast,
    bool draggable = false,
  }) {
    final done = step.status == StepStatus.done;
    final active = step.status == StepStatus.inProgress;

    String timeText;
    if (done && step.completedAt != null) {
      timeText = fmtTime(step.completedAt!);
    } else if (active && step.startedAt != null) {
      timeText = tr('Started {time}', {'time': fmtTime(step.startedAt!)});
    } else {
      timeText = '-';
    }

    return Pressable(
      onTap: () => _editStep(context, step),
      scale: 0.985,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // node + connector
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  _node(done: done, active: active),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        color: done ? AppColors.green : AppColors.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // text
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 14 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: AppText.style(
                        14,
                        active ? FontWeight.w700 : FontWeight.w600,
                        active
                            ? AppColors.darkTeal
                            : done
                            ? AppColors.textDark
                            : AppColors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(timeText, style: AppText.caption),
                    if (step.results.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 14,
                            color: AppColors.darkTeal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tr(
                              step.results.length == 1
                                  ? '{n} result document'
                                  : '{n} result documents',
                              {'n': step.results.length},
                            ),
                            style: AppText.style(
                              12,
                              FontWeight.w700,
                              AppColors.darkTeal,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (step.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 14,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              step.note,
                              style: AppText.style(
                                12,
                                FontWeight.w500,
                                AppColors.textDark,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Align(
                alignment: Alignment.topCenter,
                child: StatusPill(status: step.status),
              ),
            ),

            if (draggable)
              const Padding(
                padding: EdgeInsets.only(left: 4, top: 6),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Icon(
                    Icons.drag_indicator_rounded,
                    size: 20,
                    color: AppColors.grey,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _node({required bool done, required bool active}) {
    if (done) {
      return Container(
        width: 28,
        height: 28,
        decoration: const BoxDecoration(
          color: AppColors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 17, color: Colors.white),
      );
    }

    if (active) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.darkTeal, width: 2.5),
        ),
        child: Center(
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: AppColors.darkTeal,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
      ),
    );
  }

  // ------------------------------------------------------------
  // FAMILY ACCESS
  // ------------------------------------------------------------

  Widget _familyCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.paleTeal,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.share_location_rounded,
                  size: 21,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Progress tracking link'),
                      style: AppText.bodyStrong,
                    ),
                    Text(
                      visit.familySharing
                          ? tr('Link is active')
                          : tr('Not shared'),
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              Switch(
                value: visit.familySharing,
                activeThumbColor: Colors.white,
                activeTrackColor: AppColors.darkTeal,
                onChanged: (on) => adminStore.setFamilySharing(visit, on),
              ),
            ],
          ),
          if (visit.familySharing) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      visit.shareLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.style(
                        13,
                        FontWeight.w700,
                        AppColors.darkTeal,
                      ),
                    ),
                  ),
                  Pressable(
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: visit.shareLink),
                      );

                      if (context.mounted) {
                        showAppSnack(context, tr('Link copied.'));
                      }
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        size: 18,
                        color: AppColors.darkTeal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: visit.patientPhone.isEmpty
                  ? tr('Send via WhatsApp')
                  : tr('Send to patient ({phone})', {
                      'phone': visit.patientPhone,
                    }),
              icon: Icons.send_rounded,
              color: const Color(0xFF1FA855),
              onPressed: () => _sendWhatsApp(context),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'Shows live progress only (stages and times). No name, IC or '
                'medical details. The link stops working 2 hours after the visit ends.',
              ),
              style: AppText.caption,
            ),
            const SizedBox(height: 8),
            Pressable(
              onTap: () {
                adminStore.regenerateShareLink(visit);
                showAppSnack(
                  context,
                  tr('New link created. The old link no longer works.'),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: AppColors.red,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('Revoke and create a new link'),
                      style: AppText.style(12, FontWeight.w700, AppColors.red),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ACTIVITY LOG
  // ------------------------------------------------------------

  Widget _activityLog() {
    final entries = visit.log.reversed.take(10).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Activity log'), style: AppText.heading),
        const SizedBox(height: 4),
        Text(tr('Who updated what, and when.'), style: AppText.caption),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: cardDecoration(radius: 24),
          child: entries.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(tr('No activity yet.'), style: AppText.body),
                )
              : Column(
                  children: [
                    for (var i = 0; i < entries.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 62,
                              child: Text(
                                fmtTime(entries[i].time),
                                style: AppText.caption,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    entries[i].undone
                                        ? tr('{x} (undone)', {
                                            'x': trText(entries[i].text),
                                          })
                                        : trText(entries[i].text),
                                    style:
                                        AppText.style(
                                          13,
                                          FontWeight.w600,
                                          entries[i].undone
                                              ? AppColors.grey
                                              : AppColors.textDark,
                                        ).copyWith(
                                          decoration: entries[i].undone
                                              ? TextDecoration.lineThrough
                                              : null,
                                        ),
                                  ),
                                  Text(
                                    tr('by {x}', {
                                      'x':
                                          '${trText(entries[i].staffName)} \u00B7 '
                                          '${entries[i].staffId}',
                                    }),
                                    style: AppText.caption,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i != entries.length - 1)
                        const Divider(height: 1, color: AppColors.border),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

// ============================================================
// SHEETS
// ============================================================

class _OutcomeSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Discharge / admission decision'), style: AppText.heading),
        const SizedBox(height: 4),
        Text(
          tr('Choose the final outcome of this visit.'),
          style: AppText.caption,
        ),
        const SizedBox(height: 16),
        SheetOption(
          icon: Icons.home_outlined,
          color: AppColors.green,
          title: tr('Discharged home'),
          onTap: () => Navigator.pop(context, 'Discharged home'),
        ),
        SheetOption(
          icon: Icons.bed_outlined,
          color: AppColors.darkTeal,
          title: tr('Admitted to ward'),
          onTap: () => Navigator.pop(context, 'Admitted to ward'),
        ),
        SheetOption(
          icon: Icons.local_shipping_outlined,
          color: AppColors.yellow,
          title: tr('Transferred to another facility'),
          onTap: () =>
              Navigator.pop(context, 'Transferred to another facility'),
        ),
      ],
    );
  }
}

class _StepSheet extends StatefulWidget {
  final Visit visit;
  final VisitStep step;

  const _StepSheet({required this.visit, required this.step});

  @override
  State<_StepSheet> createState() => _StepSheetState();
}

class _StepSheetState extends State<_StepSheet> {
  late final TextEditingController noteController = TextEditingController(
    text: widget.step.note,
  );
  late final TextEditingController nameController = TextEditingController(
    text: widget.step.name,
  );

  @override
  void dispose() {
    noteController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void _save() {
    final step = widget.step;

    if (step.isTest && nameController.text.trim().isEmpty) {
      showAppSnack(context, tr('The test name cannot be empty.'));
      return;
    }

    if (step.isTest) {
      adminStore.renameStep(widget.visit, step, nameController.text);
    }
    adminStore.setNote(widget.visit, step, noteController.text);
    Navigator.pop(context);
  }

  static const _statusOptions = [
    (StepStatus.waiting, 'Waiting'),
    (StepStatus.inProgress, 'In progress'),
    (StepStatus.done, 'Done'),
  ];

  @override
  Widget build(BuildContext context) {
    // Rebuild live while the status changes with the sheet open.
    return AnimatedBuilder(
      animation: adminStore,
      builder: (context, _) => _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final visit = widget.visit;
    final step = widget.step;
    final canRemove = step.isTest && step.status == StepStatus.waiting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(step.icon, color: AppColors.darkTeal),
            const SizedBox(width: 10),
            Expanded(child: Text(step.displayName, style: AppText.heading)),
            StatusPill(status: step.status),
          ],
        ),
        const SizedBox(height: 16),

        if (step.isTest) ...[
          fieldLabel(tr('Test name')),
          const SizedBox(height: 8),
          _field(nameController, hint: tr('e.g. Chest X-ray')),
          const SizedBox(height: 16),
        ],

        fieldLabel(tr('Status')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (status, label) in _statusOptions)
              SelectChip(
                label: tr(label),
                selected: step.status == status,
                onTap: () => adminStore.setStepStatus(visit, step, status),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tr('Changes are logged with your staff ID and can be undone.'),
          style: AppText.caption,
        ),
        const SizedBox(height: 16),

        if (step.isTest) ...[
          fieldLabel(tr('Result documents')),
          const SizedBox(height: 8),
          if (step.results.isEmpty)
            Text(tr('No documents uploaded yet.'), style: AppText.caption)
          else
            for (final r in step.results)
              SheetOption(
                icon: Icons.picture_as_pdf_outlined,
                title: r.fileName,
                subtitle:
                    '${tr(r.pages == 1 ? '{n} page' : '{n} pages', {'n': r.pages})} \u00B7 '
                    '${fmtTime(r.uploadedAt)} \u00B7 ${r.staffName} (${r.staffId})',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ResultViewerPage(result: r),
                    ),
                  );
                },
              ),
          const SizedBox(height: 4),
          if (step.status == StepStatus.waiting)
            Text(
              tr('Start the test before uploading results.'),
              style: AppText.caption,
            )
          else
            SecondaryButton(
              label: tr('Scan results document'),
              onPressed: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ScanResultPage(visit: widget.visit, step: step),
                  ),
                );
              },
            ),
          const SizedBox(height: 16),
        ],

        fieldLabel(tr('Note (optional)')),
        const SizedBox(height: 8),
        _field(
          noteController,
          hint: tr('e.g. Patient moved to Radiology, Level 1'),
          lines: 3,
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: tr('Save changes'),
          icon: Icons.check_rounded,
          onPressed: _save,
        ),
        if (canRemove) ...[
          const SizedBox(height: 10),
          SecondaryButton(
            label: tr('Remove this test'),
            onPressed: () {
              adminStore.removeStep(widget.visit, step);
              Navigator.pop(context);
            },
          ),
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController controller, {
    required String hint,
    int lines = 1,
  }) {
    return TextField(
      controller: controller,
      style: AppText.input,
      maxLines: lines,
      minLines: lines == 1 ? 1 : 2,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.input.copyWith(color: AppColors.grey),
        filled: true,
        fillColor: AppColors.field,
        contentPadding: const EdgeInsets.all(14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _CustomTestInput extends StatefulWidget {
  final Visit visit;
  const _CustomTestInput({required this.visit});
  @override
  State<_CustomTestInput> createState() => _CustomTestInputState();
}

class _CustomTestInputState extends State<_CustomTestInput> {
  final controller = TextEditingController();
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void add() {
    final name = controller.text.trim();
    final id = VisitStep.slug(name);
    if (name.isEmpty || id.isEmpty) {
      setState(() => error = 'Enter a test name.');
      return;
    }
    if (widget.visit.steps.any((step) => step.id == id)) {
      setState(() => error = 'This test or stage is already in the visit.');
      return;
    }
    adminStore.addTest(widget.visit, name);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Custom test', style: AppText.heading),
      const SizedBox(height: 12),
      TextField(
        controller: controller,
        maxLength: 100,
        onSubmitted: (_) => add(),
        decoration: appInputDecoration(
          hint: 'Enter test name',
          icon: Icons.science_outlined,
        ).copyWith(errorText: error),
      ),
      const SizedBox(height: 12),
      PrimaryButton(label: 'Add custom test', icon: Icons.add, onPressed: add),
    ],
  );
}
