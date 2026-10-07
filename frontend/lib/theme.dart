import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================
// COLORS
// ============================================================

class AppColors {
  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color softTeal = Color(0xFF72D6D5);
  static const Color paleTeal = Color(0xFFE3F6F5);

  static const Color red = Color(0xFFED254E);
  static const Color orange = Color(0xFFF08A24);
  static const Color yellow = Color(0xFFE0A100);
  static const Color green = Color(0xFF2E9E6B);

  static const Color background = Color(0xFFF7F9F8);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE3EAEA);
  static const Color field = Color(0xFFF3F7F7);

  // Background gradient (soft teal tint fading to near-white).
  // For the peach look from the sample image, swap these two:
  //   gradientTop  = Color(0xFFFFE3C8)
  //   gradientGlow = Color(0xFFFFB470)
  static const Color gradientTop = Color(0xFFD3F0EF);
  static const Color gradientBottom = Color(0xFFF7FBFB);
  static const Color gradientGlow = Color(0xFF72D6D5);

  static const Color textDark = Color(0xFF183638);
  static const Color grey = Color(0xFF6B7B7D);
}

// ============================================================
// TYPOGRAPHY  (one font, small scale: 12 / 14 / 18 / 28)
// ============================================================

class AppText {
  static TextStyle style(
    double size,
    FontWeight weight,
    Color color, {
    double height = 1.4,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle get display =>
      style(28, FontWeight.w700, AppColors.textDark, height: 1.2);
  static TextStyle get heading =>
      style(18, FontWeight.w700, AppColors.textDark);
  static TextStyle get body =>
      style(14, FontWeight.w400, AppColors.grey, height: 1.5);
  static TextStyle get bodyStrong =>
      style(14, FontWeight.w700, AppColors.textDark);
  static TextStyle get caption => style(12, FontWeight.w400, AppColors.grey);
  static TextStyle get label =>
      style(12, FontWeight.w600, AppColors.textDark);
  static TextStyle get input =>
      style(14, FontWeight.w500, AppColors.textDark);
}

// ============================================================
// HELPERS
// ============================================================

BoxDecoration cardDecoration({
  double radius = 20,
  Color color = AppColors.card,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 16,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

PreferredSizeWidget buildAppBar(
  String title, {
  List<Widget>? actions,
  Widget? leading,
}) {
  return AppBar(
    backgroundColor: AppColors.background,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    leading: leading,
    iconTheme: const IconThemeData(color: AppColors.textDark),
    title: Text(title, style: AppText.heading),
    actions: actions,
  );
}

void showAppSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        content: Text(
          message,
          style: AppText.style(14, FontWeight.w500, Colors.white),
        ),
      ),
    );
}

/// Page transition: soft fade + slight slide up.
Future<T?> pushPage<T>(BuildContext context, Widget page) {
  return Navigator.of(context).push<T>(
    PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

// ============================================================
// EMERGENCY DIALOG
// ============================================================

void showEmergencyDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.red.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.phone_rounded,
            color: AppColors.red,
            size: 26,
          ),
        ),
        title: Text(
          'Emergency Services',
          textAlign: TextAlign.center,
          style: AppText.heading,
        ),
        content: Text(
          'If you are experiencing a medical emergency, call 999 immediately.',
          textAlign: TextAlign.center,
          style: AppText.body,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Close',
              style: AppText.style(14, FontWeight.w600, AppColors.grey),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            // TIP: swap this for url_launcher (tel:999) to dial directly.
            onPressed: () async {
              await Clipboard.setData(const ClipboardData(text: '999'));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (context.mounted) {
                showAppSnack(context, '999 copied. Open your dialer to call.');
              }
            },
            child: Text(
              'Copy 999',
              style: AppText.style(14, FontWeight.w700, Colors.white),
            ),
          ),
        ],
      );
    },
  );
}

// ============================================================
// REUSABLE WIDGETS
// ============================================================

/// Wraps any widget with a quick press-down scale effect.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        child: widget.child,
      ),
    );
  }
}

/// Fades and slides a widget in when it first appears.
class FadeSlideIn extends StatelessWidget {
  final Widget child;
  final int index;

  const FadeSlideIn({super.key, required this.child, this.index = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 420 + index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color color;

  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = AppColors.darkTeal,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Pressable(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? color : color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppText.style(14, FontWeight.w700, Colors.white),
            ),
            if (icon != null) ...[
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: Colors.white),
            ],
          ],
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppText.style(14, FontWeight.w700, AppColors.darkTeal),
        ),
      ),
    );
  }
}

class SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const SelectChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.darkTeal : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.darkTeal : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppText.style(
                14,
                FontWeight.w600,
                selected ? Colors.white : AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// AUTH / FORM HELPERS
// ============================================================

/// Soft gradient page background: a tinted glow at the top that fades
/// to near-white, like the sample image.
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.gradientTop, AppColors.gradientBottom],
              stops: [0.0, 0.55],
            ),
          ),
        ),
        Positioned(
          top: -110,
          right: -80,
          child: IgnorePointer(
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.gradientGlow.withValues(alpha: 0.40),
                    AppColors.gradientGlow.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class BrandWordmark extends StatelessWidget {
  final double size;

  const BrandWordmark({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: AppText.style(
          size,
          FontWeight.w800,
          AppColors.darkTeal,
          height: 1.2,
        ),
        children: const [
          TextSpan(text: 'Triage'),
          TextSpan(text: 'MY', style: TextStyle(color: AppColors.teal)),
        ],
      ),
    );
  }
}

class CircleBackButton extends StatelessWidget {
  final VoidCallback? onTap;

  const CircleBackButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap ?? () => Navigator.pop(context),
      child: Container(
        width: 42,
        height: 42,
        decoration: cardDecoration(radius: 21),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppColors.darkTeal,
        ),
      ),
    );
  }
}

class StepProgress extends StatelessWidget {
  final int current; // 0-based
  final List<String> labels;

  const StepProgress({super.key, required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(labels.length, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: i < labels.length - 1 ? 6 : 0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= current
                        ? AppColors.teal
                        : AppColors.teal.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Text(
          'Step ${current + 1} of ${labels.length} · ${labels[current]}',
          style: AppText.caption,
        ),
      ],
    );
  }
}

Widget fieldLabel(String text) => Text(text, style: AppText.bodyStrong);

InputDecoration appInputDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  OutlineInputBorder border(Color color, double width) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hint,
    hintStyle: AppText.style(14, FontWeight.w400, const Color(0xFFA5B2B2)),
    prefixIcon: Icon(icon, size: 20, color: AppColors.grey),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.field,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: border(Colors.transparent, 0),
    enabledBorder: border(Colors.transparent, 0),
    disabledBorder: border(Colors.transparent, 0),
    focusedBorder: border(AppColors.teal, 1.5),
  );
}