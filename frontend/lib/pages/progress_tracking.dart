import 'package:flutter/material.dart';

import '../theme.dart';
import 'notifications_page.dart';

class ProgressTrackingPage extends StatefulWidget {
  const ProgressTrackingPage({super.key});

  @override
  State<ProgressTrackingPage> createState() =>
      _ProgressTrackingPageState();
}

class _ProgressTrackingPageState
    extends State<ProgressTrackingPage> {
  bool showingFamily = false;

  String selectedPatientName = 'You';
  String selectedRelationship = 'Progress';
  String selectedDepartment = 'Emergency Department';
  String selectedQueue = 'A128';
  String selectedStatus = 'Waiting for X-ray';

  // ============================================================
  // NAVIGATION / ACTIONS
  // ============================================================

  void _showMyProgress() {
    setState(() {
      showingFamily = false;

      selectedPatientName = 'You';
      selectedRelationship = 'Progress';
      selectedDepartment = 'Emergency Department';
      selectedQueue = 'A128';
      selectedStatus = 'Waiting for X-ray';
    });
  }

  void _showFamily() {
    setState(() {
      showingFamily = true;
    });
  }

  void _openFamilyProgress({
    required String name,
    required String relationship,
    required String department,
    required String queue,
    required String status,
  }) {
    setState(() {
      showingFamily = false;

      selectedPatientName = name;
      selectedRelationship = relationship;
      selectedDepartment = department;
      selectedQueue = queue;
      selectedStatus = status;
    });
  }

  void _openNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationsPage(),
      ),
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

            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              32,
            ),

            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    FadeSlideIn(
                      index: 0,
                      child: _buildHeader(),
                    ),

                    const SizedBox(height: 28),

                    FadeSlideIn(
                      index: 1,
                      child: _buildTitle(),
                    ),

                    const SizedBox(height: 22),

                    FadeSlideIn(
                      index: 2,
                      child: _buildToggle(),
                    ),

                    const SizedBox(height: 24),

                    if (showingFamily)
                      FadeSlideIn(
                        index: 3,
                        child: _buildFamilySection(),
                      )
                    else ...[
                      FadeSlideIn(
                        index: 3,
                        child: _buildPatientCard(),
                      ),

                      const SizedBox(height: 28),

                      FadeSlideIn(
                        index: 4,
                        child: Text(
                          'Visit progress',
                          style: AppText.heading,
                        ),
                      ),

                      const SizedBox(height: 12),

                      FadeSlideIn(
                        index: 5,
                        child: _buildProgressTimeline(),
                      ),

                      const SizedBox(height: 24),

                      FadeSlideIn(
                        index: 6,
                        child: _buildAccessInfo(),
                      ),

                      const SizedBox(height: 18),

                      FadeSlideIn(
                        index: 7,
                        child: _buildDisclaimer(),
                      ),
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
            child: BrandWordmark(
              size: 32,
            ),
          ),
        ),

        Pressable(
          onTap: _openNotifications,

          child: Container(
            width: 42,
            height: 42,

            decoration: cardDecoration(
              radius: 14,
            ),

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

                      border: Border.all(
                        color: Colors.white,
                        width: 1.5,
                      ),
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
        Text(
          'Progress Tracking',
          style: AppText.display,
        ),

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
        color: Colors.white.withValues(
          alpha: 0.75,
        ),

        borderRadius: BorderRadius.circular(
          16,
        ),

        border: Border.all(
          color: AppColors.border,
        ),
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
        duration: const Duration(
          milliseconds: 180,
        ),

        height: 46,

        decoration: BoxDecoration(
          color: selected
              ? AppColors.darkTeal
              : Colors.transparent,

          borderRadius: BorderRadius.circular(
            13,
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 18,

              color: selected
                  ? Colors.white
                  : AppColors.grey,
            ),

            const SizedBox(width: 7),

            Text(
              label,

              style: AppText.style(
                13,
                FontWeight.w700,
                selected
                    ? Colors.white
                    : AppColors.grey,
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

      padding: const EdgeInsets.all(
        18,
      ),

      decoration: cardDecoration(
        radius: 22,
      ),

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

                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
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
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      selectedPatientName,
                      style: AppText.heading,
                    ),

                    const SizedBox(height: 2),

                    Text(
                      selectedRelationship,
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEAF7EF),

                  borderRadius:
                      BorderRadius.circular(
                    30,
                  ),
                ),

                child: Text(
                  'Active visit',

                  style: AppText.style(
                    11,
                    FontWeight.w700,
                    const Color(
                      0xFF287749,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,

            padding: const EdgeInsets.all(
              14,
            ),

            decoration: BoxDecoration(
              color: AppColors.paleTeal,

              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),

            child: Column(
              children: [
                _summaryRow(
                  icon: Icons
                      .confirmation_number_outlined,
                  label: 'Queue number',
                  value: selectedQueue,
                ),

                const SizedBox(height: 12),

                _summaryRow(
                  icon: Icons
                      .local_hospital_outlined,
                  label: 'Department',
                  value: selectedDepartment,
                ),

                const SizedBox(height: 12),

                _summaryRow(
                  icon:
                      Icons.schedule_rounded,
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
        Icon(
          icon,
          size: 18,
          color: AppColors.teal,
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Text(
            label,
            style: AppText.caption,
          ),
        ),

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

  Widget _buildFamilySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          'Family members',
          style: AppText.heading,
        ),

        const SizedBox(height: 6),

        Text(
          'View progress for people who have approved you as an emergency contact.',
          style: AppText.body,
        ),

        const SizedBox(height: 18),

        _familyCard(
          name: 'Siti Aminah',
          relationship: 'Mother',
          initials: 'SA',
          status: 'Active visit',
          currentStage:
              'Blood test completed',
          department:
              'Emergency Department',
          queue: 'B204',
          active: true,
        ),

        const SizedBox(height: 12),

        _familyCard(
          name: 'Adam Hakim',
          relationship: 'Child',
          initials: 'AH',
          status: 'Active visit',
          currentStage:
              'Waiting for doctor consultation',
          department:
              'Paediatric Department',
          queue: 'P112',
          active: true,
        ),

        const SizedBox(height: 12),

        _familyCard(
          name: 'Ahmad Rahman',
          relationship: 'Father',
          initials: 'AR',
          status: 'No active visit',
          currentStage:
              'No current hospital visit',
          department: '-',
          queue: '-',
          active: false,
        ),

        const SizedBox(height: 26),

        _buildFamilyNote(),
      ],
    );
  }

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

        padding: const EdgeInsets.all(
          16,
        ),

        decoration: cardDecoration(
          radius: 20,
        ),

        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,

              alignment: Alignment.center,

              decoration: BoxDecoration(
                color: active
                    ? AppColors.paleTeal
                    : AppColors.background,

                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),

              child: Text(
                initials,

                style: AppText.style(
                  15,
                  FontWeight.w700,
                  active
                      ? AppColors.darkTeal
                      : AppColors.grey,
                ),
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style:
                              AppText.bodyStrong,
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),

                        decoration:
                            BoxDecoration(
                          color: active
                              ? const Color(
                                  0xFFEAF7EF,
                                )
                              : const Color(
                                  0xFFF1F4F4,
                                ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            20,
                          ),
                        ),

                        child: Text(
                          status,

                          style:
                              AppText.style(
                            10,
                            FontWeight.w600,
                            active
                                ? const Color(
                                    0xFF287749,
                                  )
                                : AppColors
                                    .grey,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(
                    relationship,
                    style: AppText.caption,
                  ),

                  const SizedBox(height: 8),

                  Text(
                    currentStage,

                    style: AppText.style(
                      12,
                      FontWeight.w600,
                      active
                          ? AppColors.darkTeal
                          : AppColors.grey,
                    ),
                  ),

                  if (active) ...[
                    const SizedBox(height: 2),

                    Text(
                      department,
                      style: AppText.caption,
                    ),
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

      padding: const EdgeInsets.all(
        16,
      ),

      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.70,
        ),

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.shield_outlined,
            color: AppColors.teal,
            size: 22,
          ),

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
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        6,
      ),

      decoration: cardDecoration(
        radius: 22,
      ),

      child: Column(
        children: [
          _progressStep(
            title:
                'Registration completed',
            time: '8:12 AM',
            status: 'Done',
            state:
                VisitProgressState.completed,
            showLine: true,
          ),

          _progressStep(
            title:
                'Triage completed',
            time: '8:25 AM',
            status: 'Done',
            state:
                VisitProgressState.completed,
            showLine: true,
          ),

          _progressStep(
            title:
                'Blood test completed',
            time: '9:15 AM',
            status: 'Done',
            state:
                VisitProgressState.completed,
            showLine: true,
          ),

          _progressStep(
            title:
                'X-ray in queue',
            time: '9:30 AM',
            status: 'In progress',
            state:
                VisitProgressState.current,
            showLine: true,
          ),

          _progressStep(
            title:
                'Doctor consultation pending',
            time: '-',
            status: 'Waiting',
            state:
                VisitProgressState.pending,
            showLine: true,
          ),

          _progressStep(
            title:
                'Discharge / admission decision pending',
            time: '-',
            status: 'Waiting',
            state:
                VisitProgressState.pending,
            showLine: false,
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
    final bool completed =
        state ==
            VisitProgressState.completed;

    final bool current =
        state ==
            VisitProgressState.current;

    Color markerColor;
    Color badgeBackground;
    Color badgeText;

    if (completed) {
      markerColor =
          const Color(0xFF3BA96B);

      badgeBackground =
          const Color(0xFFEAF7EF);

      badgeText =
          const Color(0xFF287749);
    } else if (current) {
      markerColor =
          AppColors.darkTeal;

      badgeBackground =
          AppColors.paleTeal;

      badgeText =
          AppColors.darkTeal;
    } else {
      markerColor =
          const Color(0xFFBBC7C7);

      badgeBackground =
          const Color(0xFFF1F4F4);

      badgeText =
          AppColors.grey;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 36,

            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,

                  decoration: BoxDecoration(
                    color: completed
                        ? markerColor
                        : Colors.white,

                    shape: BoxShape.circle,

                    border: Border.all(
                      color: markerColor,
                      width: 2,
                    ),
                  ),

                  child: completed
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                      : current
                          ? Center(
                              child:
                                  Container(
                                width: 13,
                                height: 13,

                                decoration:
                                    const BoxDecoration(
                                  color: AppColors
                                      .darkTeal,
                                  shape: BoxShape
                                      .circle,
                                ),
                              ),
                            )
                          : null,
                ),

                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,

                      margin:
                          const EdgeInsets
                              .symmetric(
                        vertical: 3,
                      ),

                      color: completed
                          ? const Color(
                              0xFF9BD8B5,
                            )
                          : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 22,
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      Expanded(
                        child: Text(
                          title,

                          style: current
                              ? AppText.style(
                                  14,
                                  FontWeight
                                      .w700,
                                  AppColors
                                      .darkTeal,
                                )
                              : AppText
                                  .bodyStrong,
                        ),
                      ),

                      const SizedBox(
                        width: 8,
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              badgeBackground,

                          borderRadius:
                              BorderRadius
                                  .circular(
                            30,
                          ),
                        ),

                        child: Text(
                          status,

                          style:
                              AppText.style(
                            10,
                            FontWeight.w600,
                            badgeText,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    time,
                    style: AppText.caption,
                  ),
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

      padding: const EdgeInsets.all(
        16,
      ),

      decoration: cardDecoration(
        radius: 20,
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color: AppColors.paleTeal,

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
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
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  'Family visibility',
                  style: AppText.bodyStrong,
                ),

                const SizedBox(height: 3),

                Text(
                  'Approved emergency contacts may view this visit\'s progress.',
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

      padding: const EdgeInsets.all(
        16,
      ),

      decoration: BoxDecoration(
        color: Colors.white.withValues(
          alpha: 0.70,
        ),

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

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

enum VisitProgressState {
  completed,
  current,
  pending,
}


