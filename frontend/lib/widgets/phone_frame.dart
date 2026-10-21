import 'package:flutter/material.dart';

import '../theme.dart';

/// Shows the app in a fixed phone-sized canvas when the window is wider than
/// a phone (e.g. Chrome on a desktop). On an actual phone it does nothing.
///
/// The app is laid out at [phoneSize] logical pixels and scaled to fit the
/// window height, so screens look the same as on a device. MediaQuery is
/// overridden so code reading the screen size sees the phone size.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const Size phoneSize = Size(390, 844);
  static const double _frameBreakpoint = 600;
  static const double _margin = 16;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < _frameBreakpoint) return child;

    return ColoredBox(
      color: AppColors.darkTeal,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(_margin),
          child: FittedBox(
            child: Container(
              width: phoneSize.width,
              height: phoneSize.height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0, 12)),
                ],
              ),
              child: MediaQuery(
                data: media.copyWith(
                  size: phoneSize,
                  padding: EdgeInsets.zero,
                  viewPadding: EdgeInsets.zero,
                  viewInsets: EdgeInsets.zero,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
