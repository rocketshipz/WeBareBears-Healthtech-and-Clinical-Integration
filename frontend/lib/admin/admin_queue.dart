import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';
import 'admin_i18n.dart';

enum _QueueFilter { active, red, yellow, green, completed }

/// Landing screen after login: the live emergency queue.
class QueuePage extends StatefulWidget {
  final VoidCallback onRegister;
  final ValueChanged<Visit> onOpenVisit;

  const QueuePage({
    super.key,
    required this.onRegister,
    required this.onOpenVisit,
  });

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  _QueueFilter filter = _QueueFilter.active;
  String query = '';

  List<Visit> _filtered() {
    var list = adminStore.visits.toList();

    switch (filter) {
      case _QueueFilter.active:
        list = list.where((v) => !v.isComplete).toList();
        break;
      case _QueueFilter.red:
        list = list
            .where((v) => !v.isComplete && v.acuity == Acuity.red)
            .toList();
        break;
      case _QueueFilter.yellow:
        list = list
            .where((v) => !v.isComplete && v.acuity == Acuity.yellow)
            .toList();
        break;
      case _QueueFilter.green:
        list = list
            .where((v) => !v.isComplete && v.acuity == Acuity.green)
            .toList();
        break;
      case _QueueFilter.completed:
        list = list.where((v) => v.isComplete).toList();
        break;
    }

    final q = query.trim().toLowerCase();

    if (q.isNotEmpty) {
      list = list
          .where((v) =>
              v.queueNo.toLowerCase().contains(q) ||
              v.name.toLowerCase().contains(q))
          .toList();
    }

    list.sort((a, b) {
      final byZone = a.acuity.rank.compareTo(b.acuity.rank);
      if (byZone != 0) return byZone;
      return a.arrivedAt.compareTo(b.arrivedAt);
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: adminStore,
            builder: (context, _) {
              final staff = adminStore.staff;
              final visits = _filtered();

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // HEADER
                        FadeSlideIn(
                          index: 0,
                          child: Row(
                            children: [
                              const BrandWordmark(size: 28),
                              const SizedBox(width: 10),
                              const StaffTag(),
                              const Spacer(),
                              Pressable(
                                onTap: widget.onRegister,
                                child: Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.darkTeal,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.add_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        tr('New patient'),
                                        style: AppText.style(
                                          13,
                                          FontWeight.w700,
                                          Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 26),

                        // TITLE
                        FadeSlideIn(
                          index: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr(staff?.department ?? 'Emergency Department'),
                                style: AppText.display,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${staff?.hospital ?? tr('Hospital')}  ·  '
                                '${tr(staff?.role ?? tr('Staff'))} ${staff?.id ?? ''}',
                                style: AppText.body,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // STATS
                        FadeSlideIn(
                          index: 2,
                          child: Row(
                            children: [
                              Expanded(
                                child: _stat(
                                  tr('In queue'),
                                  adminStore.active.length,
                                  AppColors.darkTeal,
                                  Icons.groups_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _stat(
                                  tr('Critical'),
                                  adminStore.active
                                      .where((v) => v.acuity == Acuity.red)
                                      .length,
                                  AppColors.red,
                                  Icons.priority_high_rounded,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _stat(
                                  tr('Completed'),
                                  adminStore.completed.length,
                                  AppColors.green,
                                  Icons.check_circle_outline_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // SEARCH
                        FadeSlideIn(
                          index: 3,
                          child: TextField(
                            style: AppText.input,
                            onChanged: (v) => setState(() => query = v),
                            decoration: appInputDecoration(
                              hint: tr('Search queue no. or name'),
                              icon: Icons.search_rounded,
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // FILTERS
                        FadeSlideIn(
                          index: 4,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _chip(tr('Active'), _QueueFilter.active),
                                _chip(tr('Red'), _QueueFilter.red),
                                _chip(tr('Yellow'), _QueueFilter.yellow),
                                _chip(tr('Green'), _QueueFilter.green),
                                _chip(tr('Completed'), _QueueFilter.completed),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        if (visits.isEmpty)
                          _empty()
                        else
                          for (var i = 0; i < visits.length; i++) ...[
                            FadeSlideIn(
                              index: 5 + i,
                              child: _VisitCard(
                                visit: visits[i],
                                onTap: () => widget.onOpenVisit(visits[i]),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
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

  Widget _chip(String label, _QueueFilter value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SelectChip(
        label: label,
        selected: filter == value,
        onTap: () => setState(() => filter = value),
      ),
    );
  }

  Widget _stat(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: AppText.style(24, FontWeight.w800, AppColors.textDark),
          ),
          Text(label, style: AppText.caption),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: cardDecoration(radius: 24),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 36, color: AppColors.grey),
          const SizedBox(height: 10),
          Text(tr('No patients found'), style: AppText.bodyStrong),
          const SizedBox(height: 4),
          Text(
            tr('Try another filter or register a new patient.'),
            textAlign: TextAlign.center,
            style: AppText.caption,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VISIT CARD
// ============================================================

class _VisitCard extends StatelessWidget {
  final Visit visit;
  final VoidCallback onTap;

  const _VisitCard({required this.visit, required this.onTap});

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