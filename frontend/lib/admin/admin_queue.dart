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
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandWordmark(size: 28),
                    const SizedBox(height: 26),
                    Text(
                      'Greetings ${adminStore.staff?.name ?? 'Staff'}',
                      style: AppText.heading,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      adminStore.staff?.hospital ?? 'Hospital not assigned',
                      style: AppText.display,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminStore.staff?.department ?? 'Department not assigned',
                      style: AppText.bodyStrong,
                    ),
                    const SizedBox(height: 26),
                    Text('Patients in queue', style: AppText.display),
                    const SizedBox(height: 8),
                    Text(
                      'Select a zone to see patients and track their progress.',
                      style: AppText.body,
                    ),
                    const SizedBox(height: 24),
                    for (final zone in Acuity.values) ...[
                      Material(
                        color: zone.color,
                        borderRadius: BorderRadius.circular(22),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => open(context, zone),
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${zone.label} zone',
                                        style: AppText.style(
                                          20,
                                          FontWeight.w700,
                                          Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Patients queuing',
                                        style: AppText.style(
                                          14,
                                          FontWeight.w500,
                                          Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${adminStore.active.where((v) => v.acuity == zone).length}',
                                  style: AppText.style(
                                    36,
                                    FontWeight.w800,
                                    Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.chevron_right,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextButton(
                      onPressed: () => open(context, null),
                      child: Text(
                        'Completed visits (${adminStore.completed.length})',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
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
      widget.zone == null ? 'Completed visits' : '${widget.zone!.label} zone',
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
            Text(trText(visit.complaint), style: AppText.caption),

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
        ),
      ),
    );
  }
}
