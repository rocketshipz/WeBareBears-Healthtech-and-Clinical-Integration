import 'package:flutter/material.dart';

import '../theme.dart';
import 'hospital_homepage.dart';
import 'notifications_page.dart';
import 'profile_page.dart';
import 'triage_engine.dart';

// ============================================================
// MAIN NAVIGATION
// ============================================================

class MainNavigation extends StatefulWidget {
  final int initialIndex;

  const MainNavigation({super.key, this.initialIndex = 0});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int currentIndex = widget.initialIndex;

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();

    pages = [
      HomePage(
        onStartTriage: () {
          setState(() => currentIndex = 1);
        },
        onHospitals: () {
          setState(() => currentIndex = 2);
        },
        onMedicalHistory: () {
          setState(() => currentIndex = 3);
        },
      ),
      const TriagePage(),
      const HospitalsPage(),
      const ProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: currentIndex,
        children: pages,
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: currentIndex,
        onSelected: (index) {
          setState(() => currentIndex = index);
        },
      ),
    );
  }
}

// ============================================================
// HOME PAGE
// ============================================================

class HomePage extends StatefulWidget {
  final VoidCallback onStartTriage;
  final VoidCallback onMedicalHistory;
  final VoidCallback onHospitals;

  const HomePage({
    super.key,
    required this.onStartTriage,
    required this.onMedicalHistory,
    required this.onHospitals,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // ----------------------------------------------------------
  // HEARTBEAT
  // ----------------------------------------------------------

  late final AnimationController heartbeatController;
  late final Animation<double> heartScale;
  late final Animation<double> ringScale;
  late final Animation<double> ringOpacity;

  @override
  void initState() {
    super.initState();

    heartbeatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    )..repeat();

    // double heartbeat: beat -> beat -> rest
    heartScale = TweenSequence<double>(
      [
        TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 1.13)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 8,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.13, end: 1)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 8,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 1.08)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 7,
        ),
        TweenSequenceItem(
          tween: Tween<double>(begin: 1.08, end: 1)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 7,
        ),
        TweenSequenceItem(
          tween: ConstantTween<double>(1),
          weight: 70,
        ),
      ],
    ).animate(heartbeatController);

    final ringCurve = CurvedAnimation(
      parent: heartbeatController,
      curve: const Interval(0, 0.56, curve: Curves.easeOut),
    );

    ringScale = Tween<double>(begin: 0.78, end: 1.35).animate(ringCurve);
    ringOpacity = Tween<double>(begin: 0.32, end: 0).animate(ringCurve);
  }

  @override
  void dispose() {
    heartbeatController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // HELPERS
  // ----------------------------------------------------------

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
    );
  }

  // ----------------------------------------------------------
  // PAGE
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    FadeSlideIn(index: 1, child: _buildGreeting()),
                    const SizedBox(height: 24),
                    FadeSlideIn(index: 2, child: _buildTriageHero()),
                    ValueListenableBuilder<bool>(
                      valueListenable: profileCompleted,
                      builder: (context, done, _) {
                        if (done) return const SizedBox(height: 18);

                        return Column(
                          children: [
                            const SizedBox(height: 14),
                            FadeSlideIn(
                              index: 3,
                              child: _buildProfileReminder(),
                            ),
                            const SizedBox(height: 32),
                          ],
                        );
                      },
                    ),
                    FadeSlideIn(
                      index: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Quick access', style: AppText.heading),
                          const SizedBox(height: 12),
                          _buildQuickAccess(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    FadeSlideIn(index: 4, child: _buildHowItWorks()),
                    const SizedBox(height: 32),
                    FadeSlideIn(
                      index: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recent activity', style: AppText.heading),
                          const SizedBox(height: 12),
                          _buildRecentActivity(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildDisclaimer(),
                    const SizedBox(height: 12),
                    _buildEmergencyCard(),
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
  // GREETING
  // ============================================================

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('How are you feeling?', style: AppText.display),
        const SizedBox(height: 8),
        Text(
          'Check your symptoms and get guidance on what to do next.',
          style: AppText.body,
        ),
      ],
    );
  }

  // ============================================================
  // TRIAGE HERO
  // ============================================================

  Widget _buildTriageHero() {
    return Container(
      width: double.infinity,
      height: 256,
      decoration: BoxDecoration(
        color: AppColors.darkTeal,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkTeal.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // soft decorative glow
            Positioned(
              right: -80,
              top: -105,
              child: Container(
                width: 245,
                height: 245,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal.withValues(alpha: 0.14),
                ),
              ),
            ),

            // badge
            Positioned(
              left: 22,
              top: 22,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'Primary screening',
                  style: AppText.style(12, FontWeight.w600, Colors.white),
                ),
              ),
            ),

            // title
            Positioned(
              left: 22,
              top: 62,
              child: Text(
                'Check your\nsymptoms',
                style: AppText.style(
                  26,
                  FontWeight.w700,
                  Colors.white,
                  height: 1.2,
                ),
              ),
            ),

            // heart
            Positioned(
              right: 6,
              top: 40,
              child: _buildHeart(),
            ),

            // ECG line
            const Positioned(
              left: 22,
              right: 22,
              bottom: 74,
              child: SizedBox(
                height: 34,
                child: CustomPaint(painter: HeroEcgPainter()),
              ),
            ),

            // CTA
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Pressable(
                onTap: widget.onStartTriage,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.monitor_heart_outlined,
                        size: 18,
                        color: AppColors.darkTeal,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Start triage',
                        style: AppText.style(
                          14,
                          FontWeight.w700,
                          AppColors.darkTeal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.darkTeal,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEART
  // ============================================================

  Widget _buildHeart() {
    return SizedBox(
      width: 142,
      height: 142,
      child: AnimatedBuilder(
        animation: heartbeatController,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // animated ring
              Transform.scale(
                scale: ringScale.value,
                child: Opacity(
                  opacity: ringOpacity.value,
                  child: Container(
                    width: 83,
                    height: 83,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.softTeal,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

              // glow
              Container(
                width: 91,
                height: 91,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal.withValues(alpha: 0.08),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.softTeal.withValues(alpha: 0.18),
                      blurRadius: 27,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),

              // beating heart
              Transform.scale(
                scale: heartScale.value,
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 78,
                      color: AppColors.softTeal,
                    ),
                    SizedBox(
                      width: 52,
                      height: 28,
                      child: CustomPaint(painter: MiniHeartEcgPainter()),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================
  // MEDICAL PROFILE REMINDER
  // ============================================================

  Widget _buildProfileReminder() {
    return Pressable(
      onTap: widget.onMedicalHistory,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.paleTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_information_outlined,
                color: AppColors.teal,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete your medical profile',
                    style: AppText.bodyStrong,
                  ),
                  Text(
                    'Help us provide more relevant guidance.',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: AppColors.darkTeal,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Complete',
                style: AppText.style(12, FontWeight.w700, Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUICK ACCESS
  // ============================================================

  Widget _buildQuickAccess() {
    return Row(
      children: [
        Expanded(
          child: _quickAccessCard(
            icon: Icons.favorite_outline_rounded,
            title: 'Medical History',
            subtitle: 'Your health information',
            onTap: widget.onMedicalHistory,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _quickAccessCard(
            icon: Icons.local_hospital_outlined,
            title: 'Hospitals',
            subtitle: 'Find appropriate care',
            onTap: widget.onHospitals,
          ),
        ),
      ],
    );
  }

  Widget _quickAccessCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 148,
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.paleTeal,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.teal, size: 21),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(child: Text(title, style: AppText.bodyStrong)),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.grey,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: AppText.caption),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HOW IT WORKS
  // ============================================================

  Widget _buildHowItWorks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('How TriageMY works', style: AppText.heading),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: AppColors.paleTeal,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '3 steps',
                style: AppText.style(12, FontWeight.w700, AppColors.darkTeal),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 18),
          decoration: cardDecoration(radius: 22),
          child: Row(
            children: [
              Expanded(
                child: _stepItem(
                  number: '1',
                  icon: Icons.chat_bubble_outline_rounded,
                  title: 'Tell us',
                  subtitle: 'Your symptoms',
                ),
              ),
              _stepArrow(),
              Expanded(
                child: _stepItem(
                  number: '2',
                  icon: Icons.monitor_heart_outlined,
                  title: 'Screen',
                  subtitle: 'Check urgency',
                ),
              ),
              _stepArrow(),
              Expanded(
                child: _stepItem(
                  number: '3',
                  icon: Icons.route_outlined,
                  title: 'Guide',
                  subtitle: 'Next steps',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepItem({
    required String number,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.paleTeal,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: AppColors.teal, size: 22),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.darkTeal,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: AppText.style(12, FontWeight.w700, Colors.white,
                      height: 1),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(title, style: AppText.label),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: AppText.caption,
        ),
      ],
    );
  }

  Widget _stepArrow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 34),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 16,
        color: AppColors.teal.withValues(alpha: 0.5),
      ),
    );
  }

  // ============================================================
  // RECENT ACTIVITY
  // ============================================================

  Widget _buildRecentActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(radius: 22),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.paleTeal,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: AppColors.teal,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No recent triage', style: AppText.bodyStrong),
                Text(
                  'Your latest screening result will appear here.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.arrow_forward_rounded,
              size: 15,
              color: AppColors.grey,
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
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.teal, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preliminary screening only',
                  style: AppText.style(14, FontWeight.w700, AppColors.darkTeal),
                ),
                const SizedBox(height: 2),
                Text(
                  'TriageMY does not diagnose conditions or replace assessment by a healthcare professional.',
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
  // EMERGENCY
  // ============================================================

  Widget _buildEmergencyCard() {
    return Pressable(
      onTap: _showEmergencyDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.red.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.red.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.red.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.phone_in_talk_rounded,
                color: AppColors.red,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Need urgent help?', style: AppText.bodyStrong),
                  Text(
                    'For a medical emergency, call 999.',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '999',
                style: AppText.style(14, FontWeight.w700, Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppColors.red.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: AppColors.red,
                  size: 27,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Emergency Services',
                textAlign: TextAlign.center,
                style: AppText.heading,
              ),
              const SizedBox(height: 8),
              Text(
                'If you are experiencing a medical emergency, call 999 immediately.',
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Close',
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================
// HERO ECG
// ============================================================

class HeroEcgPainter extends CustomPainter {
  const HeroEcgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9BE7E5).withValues(alpha: 0.72)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final y = size.height / 2;

    final path = Path()
      ..moveTo(0, y)
      ..lineTo(size.width * 0.13, y)
      ..lineTo(size.width * 0.18, y - 3)
      ..lineTo(size.width * 0.23, y)
      ..lineTo(size.width * 0.29, y)
      ..lineTo(size.width * 0.33, y + 6)
      ..lineTo(size.width * 0.38, y - 17)
      ..lineTo(size.width * 0.43, y + 13)
      ..lineTo(size.width * 0.48, y)
      ..lineTo(size.width * 0.64, y)
      ..lineTo(size.width * 0.69, y - 4)
      ..lineTo(size.width * 0.74, y)
      ..lineTo(size.width, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ============================================================
// ECG INSIDE HEART
// ============================================================

class MiniHeartEcgPainter extends CustomPainter {
  const MiniHeartEcgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final y = size.height / 2;
    final w = size.width;

    final path = Path()
      ..moveTo(0, y)
      ..lineTo(w * 0.19, y)
      ..lineTo(w * 0.29, y - 3)
      ..lineTo(w * 0.40, y + 4)
      ..lineTo(w * 0.52, y - 10)
      ..lineTo(w * 0.64, y + 10)
      ..lineTo(w * 0.75, y)
      ..lineTo(w, y);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// ============================================================
// SHARED BOTTOM NAV (also used on pushed pages)
// ============================================================

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppBottomNav({
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
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) {
              final selected = states.contains(WidgetState.selected);

              return AppText.style(
                12,
                selected ? FontWeight.w700 : FontWeight.w500,
                selected ? AppColors.darkTeal : AppColors.grey,
              );
            },
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon:
                  Icon(Icons.home_rounded, color: AppColors.darkTeal),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.monitor_heart_outlined),
              selectedIcon:
                  Icon(Icons.monitor_heart_rounded, color: AppColors.darkTeal),
              label: 'Triage',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_hospital_outlined),
              selectedIcon:
                  Icon(Icons.local_hospital_rounded, color: AppColors.darkTeal),
              label: 'Hospitals',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon:
                  Icon(Icons.person_rounded, color: AppColors.darkTeal),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}