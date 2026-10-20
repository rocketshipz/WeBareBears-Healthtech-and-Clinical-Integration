import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';
import 'admin_i18n.dart';

class QueuePage extends StatelessWidget {
  final VoidCallback onRegister;
  final ValueChanged<Visit> onOpenVisit;
  const QueuePage({
    super.key,
    required this.onRegister,
    required this.onOpenVisit,
  });

  void open(BuildContext context, Acuity? zone) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _ZonePatientsPage(zone: zone, onOpenVisit: onOpenVisit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: GradientBackground(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: adminStore,
          builder: (context, _) {
            final active = adminStore.active;
            final hour = DateTime.now()
                .toUtc()
                .add(const Duration(hours: 8))
                .hour;
            final greeting = hour < 12
                ? 'Good morning'
                : hour < 18
                ? 'Good afternoon'
                : 'Good evening';
            return LayoutBuilder(
              builder: (context, viewport) => SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (viewport.maxHeight - 48).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BrandWordmark(size: 32),
                          const SizedBox(height: 22),
                          Text(
                            '${tr(greeting)}, ${adminStore.staff?.name ?? tr('Staff')}',
                            textAlign: TextAlign.left,
                            style: AppText.style(
                              13,
                              FontWeight.w600,
                              AppColors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adminStore.staff?.hospital ??
                                tr('Hospital not assigned'),
                            textAlign: TextAlign.left,
                            style: AppText.style(
                              24,
                              FontWeight.w800,
                              AppColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.start,
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  adminStore.staff?.department ??
                                      tr('Department not assigned'),
                                  style: AppText.style(
                                    11,
                                    FontWeight.w700,
                                    AppColors.darkTeal,
                                  ),
                                ),
                              ),
                              ValueListenableBuilder<String?>(
                                valueListenable: adminStore.syncError,
                                builder: (context, error, _) => Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: error == null
                                            ? AppColors.green
                                            : AppColors.orange,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                (error == null
                                                        ? AppColors.green
                                                        : AppColors.orange)
                                                    .withValues(alpha: 0.2),
                                            blurRadius: 5,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      tr(
                                        error == null
                                            ? 'Live'
                                            : 'Sync unavailable',
                                      ),
                                      style: AppText.caption,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF35B7C0), Color(0xFF0D5C63)],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.darkTeal.withValues(
                                    alpha: 0.20,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 9),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${active.length}',
                                  key: const ValueKey('queue-total'),
                                  style: AppText.style(
                                    60,
                                    FontWeight.w800,
                                    Colors.white,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  tr('patients in queue'),
                                  style: AppText.style(
                                    15,
                                    FontWeight.w600,
                                    Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Material(
                                  color: Colors.white.withValues(alpha: 0.20),
                                  borderRadius: BorderRadius.circular(30),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: () => open(context, null),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            tr('Completed visits'),
                                            style: AppText.style(
                                              13,
                                              FontWeight.w700,
                                              Colors.white,
                                            ),
                                          ),
                                          Text(
                                            '${adminStore.completed.length}',
                                            key: const ValueKey(
                                              'queue-completed',
                                            ),
                                            style: AppText.style(
                                              14,
                                              FontWeight.w700,
                                              Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            tr('Queue by zone'),
                            textAlign: TextAlign.left,
                            style: AppText.heading,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tr(
                              'Tap a zone to see patients and track their progress.',
                            ),
                            textAlign: TextAlign.left,
                            style: AppText.caption,
                          ),
                          const SizedBox(height: 12),
                          GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            mainAxisExtent: 166,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              for (final zone in Acuity.values)
                                _ZoneTile(
                                  zone: zone,
                                  count: active
                                      .where((v) => v.acuity == zone)
                                      .length,
                                  total: active.length,
                                  onTap: () => open(context, zone),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

class _ZoneTile extends StatelessWidget {
  final Acuity zone;
  final int count;
  final int total;
  final VoidCallback onTap;
  const _ZoneTile({
    required this.zone,
    required this.count,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = switch (zone) {
      Acuity.red => const Color(0xFFFFE5EB),
      Acuity.yellow => const Color(0xFFFFF2CB),
      Acuity.green => const Color(0xFFDDF3EA),
      Acuity.pending => const Color(0xFFE8EFF0),
    };
    final title = zone == Acuity.pending
        ? tr('Pending triage')
        : tr('{zone} zone', {'zone': zone.label});
    final description = zone == Acuity.pending
        ? tr('Awaiting assessment')
        : zone.description;
    return Semantics(
      button: true,
      label: '$title: $count ${tr('patients in queue')}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('queue-zone-${zone.name}'),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 82,
                  height: 82,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: total == 0 ? 0 : count / total,
                          strokeWidth: 7,
                          strokeCap: StrokeCap.round,
                          backgroundColor: Colors.white.withValues(alpha: 0.85),
                          color: zone.color,
                        ),
                      ),
                      Text(
                        '$count',
                        style: AppText.style(
                          34,
                          FontWeight.w800,
                          count == 0 ? AppColors.grey : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: AppText.style(
                      14,
                      FontWeight.w800,
                      AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    description,
                    style: AppText.style(11, FontWeight.w500, AppColors.grey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ZonePatientsPage extends StatefulWidget {
  final Acuity? zone;
  final ValueChanged<Visit> onOpenVisit;
  const _ZonePatientsPage({required this.zone, required this.onOpenVisit});
  @override
  State<_ZonePatientsPage> createState() => _ZonePatientsPageState();
}

class _ZonePatientsPageState extends State<_ZonePatientsPage> {
  String query = '';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: buildAppBar(
      widget.zone == null
          ? 'Completed visits'
          : widget.zone == Acuity.pending
          ? 'Pending Triage'
          : '${widget.zone!.label} zone',
    ),
    body: AnimatedBuilder(
      animation: adminStore,
      builder: (context, _) {
        final visits =
            adminStore.visits
                .where(
                  (v) =>
                      (widget.zone == null
                          ? v.isComplete
                          : !v.isComplete && v.acuity == widget.zone) &&
                      ('${v.name} ${v.queueNo} ${v.ic}'.toLowerCase().contains(
                        query.toLowerCase(),
                      )),
                )
                .toList()
              ..sort((a, b) => a.arrivedAt.compareTo(b.arrivedAt));
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                TextField(
                  onChanged: (value) => setState(() => query = value),
                  decoration: appInputDecoration(
                    hint: 'Search name, queue number or IC',
                    icon: Icons.search,
                  ),
                ),
                const SizedBox(height: 20),
                Text('${visits.length} patients', style: AppText.heading),
                const SizedBox(height: 16),
                if (visits.isEmpty)
                  Text('No patients in this queue.', style: AppText.body),
                for (final visit in visits)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PatientVisitCard(
                      visit: visit,
                      onTap: () => widget.onOpenVisit(visit),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class PatientVisitCard extends StatelessWidget {
  final Visit visit;
  final VoidCallback onTap;

  const PatientVisitCard({super.key, required this.visit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final complete = visit.isComplete;
    DateTime? dischargedAt = visit.completedAt;
    if (dischargedAt == null) {
      for (final step in visit.steps) {
        if (step.id == 'discharge') dischargedAt = step.completedAt;
      }
    }
    final localDischarge = dischargedAt?.toLocal();
    final dischargeLabel = localDischarge == null
        ? 'Discharge date unavailable'
        : 'Discharged ${localDischarge.day}/${localDischarge.month}/${localDischarge.year} at ${fmtTime(localDischarge)}';

    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  visit.queueNo,
                  style: AppText.style(20, FontWeight.w800, AppColors.textDark),
                ),
                const SizedBox(width: 10),
                AcuityPill(acuity: visit.acuity),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.grey,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(visit.name, style: AppText.bodyStrong),
            Text(
              complete
                  ? 'Diagnosis: ${visit.diagnosis?.trim().isNotEmpty == true ? visit.diagnosis!.trim() : 'Not recorded'}'
                  : trText(visit.complaint),
              style: AppText.caption,
            ),
            if (complete) ...[
              const SizedBox(height: 8),
              Text(dischargeLabel, style: AppText.caption),
            ],
            if (!complete) ...[
              const SizedBox(height: 14),

              // segmented progress
              Row(
                children: [
                  for (final s in visit.steps)
                    Expanded(
                      child: Container(
                        height: 6,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: s.status == StepStatus.done
                              ? AppColors.green
                              : s.status == StepStatus.inProgress
                              ? AppColors.darkTeal
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(
                    complete
                        ? Icons.check_circle_rounded
                        : Icons.timelapse_rounded,
                    size: 17,
                    color: complete ? AppColors.green : AppColors.darkTeal,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      visit.statusText,
                      style: AppText.style(
                        13,
                        FontWeight.w700,
                        complete ? AppColors.green : AppColors.darkTeal,
                      ),
                    ),
                  ),
                  Text(
                    tr('Updated {ago}', {'ago': agoText(visit.lastUpdated)}),
                    style: AppText.caption,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
