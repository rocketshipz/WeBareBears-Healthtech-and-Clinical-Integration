import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_i18n.dart';
import 'admin_models.dart';

// ============================================================
// FORMATTING
// ============================================================

String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  final suffix = d.hour < 12 ? 'AM' : 'PM';

  return '$h:$m $suffix';
}

String agoText(DateTime d) {
  final minutes = DateTime.now().difference(d).inMinutes;

  if (minutes < 1) return tr('Just now');
  if (minutes < 60) return tr('{n} min ago', {'n': minutes});

  final h = minutes ~/ 60;
  final m = minutes % 60;

  return m == 0
      ? tr('{h}h ago', {'h': h})
      : tr('{h}h {m}m ago', {'h': h, 'm': m});
}

// ============================================================
// ACUITY PILL
// ============================================================

class AcuityPill extends StatelessWidget {
  final Acuity acuity;
  final bool showDescription;

  const AcuityPill({
    super.key,
    required this.acuity,
    this.showDescription = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = acuity.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            showDescription
                ? '${acuity.label} · ${acuity.description}'
                : acuity.label,
            style: AppText.style(12, FontWeight.w700, color),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STATUS PILL  (Done / In progress / Waiting)
// ============================================================

class StatusPill extends StatelessWidget {
  final StepStatus status;

  const StatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    late final String text;

    switch (status) {
      case StepStatus.done:
        bg = AppColors.green.withValues(alpha: 0.12);
        fg = AppColors.green;
        text = tr('Done');
        break;
      case StepStatus.inProgress:
        bg = AppColors.paleTeal;
        fg = AppColors.darkTeal;
        text = tr('In progress');
        break;
      case StepStatus.waiting:
        bg = AppColors.field;
        fg = AppColors.grey;
        text = tr('Waiting');
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: AppText.style(12, FontWeight.w600, fg)),
    );
  }
}

// ============================================================
// BOTTOM SHEET HELPER
// ============================================================

Future<T?> showStaffSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          14,
          24,
          28 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              builder(sheetContext),
            ],
          ),
        ),
      );
    },
  );
}

/// A tappable row used inside sheets.
class SheetOption extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const SheetOption({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color = AppColors.darkTeal,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : AppColors.field,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.bodyStrong),
                    if (subtitle != null)
                      Text(subtitle!, style: AppText.caption),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STAFF BOTTOM NAV  (Queue / Register / Account)
// ============================================================

class StaffBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const StaffBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: NavigationBar(
          height: 68,
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.paleTeal,
          selectedIndex: selectedIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: onSelected,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);

            return AppText.style(
              12,
              selected ? FontWeight.w700 : FontWeight.w500,
              selected ? AppColors.darkTeal : AppColors.grey,
            );
          }),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_rounded),
              selectedIcon: const Icon(
                Icons.home_rounded,
                color: AppColors.darkTeal,
              ),
              label: tr('Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_add_alt_outlined),
              selectedIcon: const Icon(
                Icons.person_add_alt_1_rounded,
                color: AppColors.darkTeal,
              ),
              label: tr('Check-In'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: const Icon(
                Icons.people_rounded,
                color: AppColors.darkTeal,
              ),
              label: tr('Patients'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.badge_outlined),
              selectedIcon: const Icon(
                Icons.badge_rounded,
                color: AppColors.darkTeal,
              ),
              label: tr('Account'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SMALL SHARED PIECES
// ============================================================

/// "Staff" tag shown beside the brand so it is obvious this is the hospital app.
class StaffTag extends StatelessWidget {
  const StaffTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.darkTeal,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'HOSPITAL',
        style: AppText.style(11, FontWeight.w800, Colors.white, height: 1.2),
      ),
    );
  }
}

// ============================================================
// LANGUAGE TOGGLE  (EN | BM)
// ============================================================

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdminLang>(
      valueListenable: adminLang,
      builder: (context, current, _) {
        return Semantics(
          label: tr('Language'),
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 6, right: 4),
                  child: Icon(
                    Icons.translate_rounded,
                    size: 16,
                    color: AppColors.teal,
                  ),
                ),
                for (final lang in AdminLang.values)
                  Tooltip(
                    message: lang.label,
                    child: Pressable(
                      onTap: () => setAdminLang(lang),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: current == lang
                              ? AppColors.darkTeal
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          lang.code,
                          style: AppText.style(
                            12,
                            FontWeight.w800,
                            current == lang ? Colors.white : AppColors.grey,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
