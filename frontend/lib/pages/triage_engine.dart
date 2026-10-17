import '../localization.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'triage_report.dart';

class TriagePage extends StatefulWidget {
  const TriagePage({super.key});

  @override
  State<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends State<TriagePage> {
  String? selectedSymptom;
  String? selectedSeverity;
  String? selectedDuration;

  final Set<String> selectedDangerSigns = {};

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BAR
                    FadeSlideIn(
                      index: 0,
                      child: Row(
                        children: [
                          CircleBackButton(
                            onTap: () {
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 14),
                          const BrandWordmark(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // PAGE TITLE
                    FadeSlideIn(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText('AI Triage', style: AppText.display),
                          const SizedBox(height: 8),
                          LocalizedText(
                            'Answer a few questions to help us understand your condition.',
                            style: AppText.body,
                          ),
                          const SizedBox(height: 22),

                          // PROGRESS
                          Row(
                            children: [
                              LocalizedText(
                                'Step 1',
                                style: AppText.style(
                                  12,
                                  FontWeight.w700,
                                  AppColors.darkTeal,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: LinearProgressIndicator(
                                    value: 0.5,
                                    minHeight: 6,
                                    backgroundColor:
                                        AppColors.teal.withValues(alpha: 0.18),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                      AppColors.teal,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // QUESTION 1
                    FadeSlideIn(
                      index: 2,
                      child: _questionCard(
                        number: '1',
                        title: 'What are you feeling?',
                        subtitle: 'Select the main symptom.',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _option(
                              text: 'Fever',
                              icon: Icons.thermostat_rounded,
                              selected: selectedSymptom == 'Fever',
                              onTap: () {
                                setState(() {
                                  selectedSymptom = 'Fever';
                                });
                              },
                            ),
                            _option(
                              text: 'Cough',
                              icon: Icons.air_rounded,
                              selected: selectedSymptom == 'Cough',
                              onTap: () {
                                setState(() {
                                  selectedSymptom = 'Cough';
                                });
                              },
                            ),
                            _option(
                              text: 'Stomach pain',
                              icon: Icons.sick_outlined,
                              selected: selectedSymptom == 'Stomach pain',
                              onTap: () {
                                setState(() {
                                  selectedSymptom = 'Stomach pain';
                                });
                              },
                            ),
                            _option(
                              text: 'Minor injury',
                              icon: Icons.healing_rounded,
                              selected: selectedSymptom == 'Minor injury',
                              onTap: () {
                                setState(() {
                                  selectedSymptom = 'Minor injury';
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // QUESTION 2
                    FadeSlideIn(
                      index: 3,
                      child: _questionCard(
                        number: '2',
                        title: 'How severe is it?',
                        subtitle:
                            'Choose the level that best describes your condition.',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _option(
                              text: 'Mild',
                              icon: Icons.signal_cellular_alt_1_bar_rounded,
                              selected: selectedSeverity == 'Mild',
                              onTap: () {
                                setState(() {
                                  selectedSeverity = 'Mild';
                                });
                              },
                            ),
                            _option(
                              text: 'Moderate',
                              icon: Icons.signal_cellular_alt_2_bar_rounded,
                              selected: selectedSeverity == 'Moderate',
                              onTap: () {
                                setState(() {
                                  selectedSeverity = 'Moderate';
                                });
                              },
                            ),
                            _option(
                              text: 'Severe',
                              icon: Icons.signal_cellular_alt_rounded,
                              selected: selectedSeverity == 'Severe',
                              onTap: () {
                                setState(() {
                                  selectedSeverity = 'Severe';
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // QUESTION 3
                    FadeSlideIn(
                      index: 4,
                      child: _questionCard(
                        number: '3',
                        title: 'How long have you had it?',
                        subtitle: 'Select the duration.',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _option(
                              text: 'Less than\n24 hours',
                              icon: Icons.schedule_rounded,
                              selected:
                                  selectedDuration == 'Less than 24 hours',
                              onTap: () {
                                setState(() {
                                  selectedDuration = 'Less than 24 hours';
                                });
                              },
                            ),
                            _option(
                              text: '1–3 days',
                              icon: Icons.calendar_today_outlined,
                              selected: selectedDuration == '1–3 days',
                              onTap: () {
                                setState(() {
                                  selectedDuration = '1–3 days';
                                });
                              },
                            ),
                            _option(
                              text: 'More than\n3 days',
                              icon: Icons.date_range_outlined,
                              selected:
                                  selectedDuration == 'More than 3 days',
                              onTap: () {
                                setState(() {
                                  selectedDuration = 'More than 3 days';
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // QUESTION 4
                    FadeSlideIn(
                      index: 5,
                      child: _questionCard(
                        number: '4',
                        title: 'Any danger signs?',
                        subtitle: 'Select all that apply.',
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _dangerOption(
                              text: 'Difficulty\nbreathing',
                              icon: Icons.air_rounded,
                            ),
                            _dangerOption(
                              text: 'Heavy\nbleeding',
                              icon: Icons.water_drop_outlined,
                            ),
                            _dangerOption(
                              text: 'Chest pain',
                              icon: Icons.favorite_border_rounded,
                            ),
                            _dangerOption(
                              text: 'None of these',
                              icon: Icons.block_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // EMERGENCY WARNING
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.red.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: AppColors.red.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.red.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.red,
                              size: 21,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: LocalizedText(
                              'If you are experiencing emergency warning signs, '
                              'call 999 or seek emergency medical care immediately.',
                              style: AppText.style(
                                12,
                                FontWeight.w600,
                                AppColors.textDark,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // CONTINUE BUTTON
                    PrimaryButton(
                      label: 'Finish triage',
                      icon: Icons.arrow_forward_rounded,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TriageReportPage(
                              report: TriageReportData(
                                symptom: selectedSymptom,
                                severity: selectedSeverity,
                                duration: selectedDuration,
                                dangerSigns: selectedDangerSigns,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
  // QUESTION CONTAINER
  // ============================================================

  Widget _questionCard({
    required String number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.darkTeal,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: LocalizedText(
                    number,
                    style: AppText.style(14, FontWeight.w700, Colors.white,
                        height: 1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(title, style: AppText.heading),
                    const SizedBox(height: 2),
                    LocalizedText(subtitle, style: AppText.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  // ============================================================
  // NORMAL SINGLE-SELECT OPTION
  // ============================================================

  Widget _option({
    required String text,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 135,
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: _optionDecoration(selected),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 27,
              color: selected ? AppColors.teal : AppColors.darkTeal,
            ),
            const SizedBox(height: 8),
            LocalizedText(
              text,
              textAlign: TextAlign.center,
              style: _optionTextStyle(selected),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MULTI-SELECT DANGER SIGN OPTION
  // ============================================================

  Widget _dangerOption({
    required String text,
    required IconData icon,
  }) {
    final bool selected = selectedDangerSigns.contains(text);

    return Pressable(
      onTap: () {
        setState(() {
          if (text == 'None of these') {
            selectedDangerSigns.clear();
            selectedDangerSigns.add(text);
          } else {
            selectedDangerSigns.remove('None of these');

            if (selected) {
              selectedDangerSigns.remove(text);
            } else {
              selectedDangerSigns.add(text);
            }
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 135,
        height: 100,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: _optionDecoration(selected),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 27,
                    color: selected ? AppColors.teal : AppColors.darkTeal,
                  ),
                  const SizedBox(height: 8),
                  LocalizedText(
                    text,
                    textAlign: TextAlign.center,
                    style: _optionTextStyle(selected),
                  ),
                ],
              ),
            ),
            if (selected)
              const Positioned(
                top: 0,
                right: 0,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _optionDecoration(bool selected) {
    return BoxDecoration(
      color: selected
          ? AppColors.teal.withValues(alpha: 0.10)
          : AppColors.field,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: selected ? AppColors.teal : AppColors.border,
        width: selected ? 1.5 : 1,
      ),
    );
  }

  TextStyle _optionTextStyle(bool selected) {
    return AppText.style(
      14,
      selected ? FontWeight.w700 : FontWeight.w500,
      AppColors.darkTeal,
      height: 1.15,
    );
  }
}