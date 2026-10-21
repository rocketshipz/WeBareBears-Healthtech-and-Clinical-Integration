import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Shows the app inside an iPhone-style frame when it runs in a desktop
/// browser (e.g. Chrome on a laptop). On a phone, whether the native app or
/// the website opened in a mobile browser, it does nothing.
///
/// The app is laid out at [screenSize] logical pixels and scaled to fit the
/// window height, so screens look the same as on a device. MediaQuery is
/// overridden so code reading the screen size sees the phone size, and the
/// safe-area padding keeps content clear of the status bar and home indicator.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});

  final Widget child;

  static const Size screenSize = Size(390, 844);
  static const double _frameBreakpoint = 600;
  static const double _margin = 16;

  static const double _bezel = 12;
  static const double _screenRadius = 47;
  static const double _buttonDepth = 3;
  static const double _statusBarHeight = 47;
  static const double _homeIndicatorHeight = 34;

  static const Color _body = Color(0xFF1C1C1E);
  static const Color _bezelColor = Colors.black;

  /// Mobile browsers report Android/iOS here, desktop browsers report the
  /// desktop OS, so the frame never appears on a phone.
  static bool get _isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (!_isDesktop || media.size.width < _frameBreakpoint) return child;

    const deviceWidth = 390 + _bezel * 2;
    const deviceHeight = 844 + _bezel * 2;

    return ColoredBox(
      color: AppColors.darkTeal,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(_margin),
          child: FittedBox(
            child: SizedBox(
              width: deviceWidth + _buttonDepth * 2,
              height: deviceHeight,
              child: Stack(
                children: [
                  // Side buttons: action + volume on the left, power on the right.
                  _sideButton(left: 0, top: 120, height: 32),
                  _sideButton(left: 0, top: 180, height: 62),
                  _sideButton(left: 0, top: 256, height: 62),
                  _sideButton(right: 0, top: 210, height: 98),
                  Positioned(
                    left: _buttonDepth,
                    top: 0,
                    width: deviceWidth,
                    height: deviceHeight,
                    child: Container(
                      padding: const EdgeInsets.all(_bezel),
                      decoration: BoxDecoration(
                        color: _bezelColor,
                        borderRadius: BorderRadius.circular(_screenRadius + _bezel),
                        border: Border.all(color: _body, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 40, offset: Offset(0, 16)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_screenRadius),
                        child: SizedBox.fromSize(
                          size: screenSize,
                          child: _screen(media),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _screen(MediaQueryData media) {
    const safeArea = EdgeInsets.only(top: _statusBarHeight, bottom: _homeIndicatorHeight);
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: AppColors.background,
            child: MediaQuery(
              data: media.copyWith(
                size: screenSize,
                padding: safeArea,
                viewPadding: safeArea,
                viewInsets: EdgeInsets.zero,
              ),
              child: child,
            ),
          ),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _statusBarHeight,
          child: IgnorePointer(child: _StatusBar()),
        ),
        // Home indicator.
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: 134,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.textDark,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _sideButton({double? left, double? right, required double top, required double height}) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      width: _buttonDepth + 2,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _body,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Time, Dynamic Island and signal / wifi / battery, like an iPhone status bar.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const color = AppColors.textDark;
    return Stack(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.only(top: 11),
            width: 122,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(42, 15, 30, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '9:41',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(Icons.signal_cellular_alt, size: 17, color: color),
                    SizedBox(width: 4),
                    Icon(Icons.wifi, size: 17, color: color),
                    SizedBox(width: 5),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _battery(color),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _battery(Color color) {
    return Row(
      children: [
        Container(
          width: 25,
          height: 12,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(left: 1),
          width: 1.5,
          height: 4,
          color: color.withValues(alpha: 0.45),
        ),
      ],
    );
  }
}
