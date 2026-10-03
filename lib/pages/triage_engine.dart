import 'package:flutter/material.dart';
import 'hospital_routing.dart';

class TriagePage extends StatefulWidget {
  const TriagePage({super.key});

  @override
  State<TriagePage> createState() => _TriagePageState();
}

class _TriagePageState extends State<TriagePage> {
  // Same colour direction as the existing TriageMY styling
  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color red = Color(0xFFED254E);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color background = Color(0xFFF7FBFB);
  static const Color optionBackground = Color(0xFFF3F7F7);

  String? selectedSymptom;
  String? selectedSeverity;
  String? selectedDuration;

  final Set<String> selectedDangerSigns = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: darkTeal,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            children: [
              TextSpan(
                text: 'Triage',
                style: TextStyle(color: darkTeal),
              ),
              TextSpan(
                text: 'MY',
                style: TextStyle(color: teal),
              ),
            ],
          ),
        ),
        centerTitle: false,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PAGE TITLE
                  const Text(
                    'AI Triage',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: darkTeal,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Answer a few questions to help us understand your condition.',
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 15,
                      height: 1.4,
                      color: grey,
                    ),
                  ),

                  const SizedBox(height: 26),

                  // PROGRESS
                  Row(
                    children: [
                      const Text(
                        'Step 1',
                        style: TextStyle(
                          fontFamily: 'Helvetica',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: darkTeal,
                        ),
                      ),

                      const SizedBox(width: 14),

                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: const LinearProgressIndicator(
                            value: 0.5,
                            minHeight: 7,
                            backgroundColor: Color(0xFFE5EEEE),
                            valueColor:
                                AlwaysStoppedAnimation<Color>(teal),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // QUESTION 1
                  _questionCard(
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

                  const SizedBox(height: 16),

                  // QUESTION 2
                  _questionCard(
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

                  const SizedBox(height: 16),

                  // QUESTION 3
                  _questionCard(
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

                  const SizedBox(height: 16),

                  // QUESTION 4
                  _questionCard(
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

                  const SizedBox(height: 20),

                  // EMERGENCY WARNING
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: red.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.warning_amber_rounded,
                            color: red,
                            size: 21,
                          ),
                        ),

                        const SizedBox(width: 12),

                        const Expanded(
                          child: Text(
                            'If you are experiencing emergency warning signs, '
                            'call 999 or seek emergency medical care immediately.',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 13,
                              height: 1.45,
                              color: darkTeal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // CONTINUE BUTTON
SizedBox(
  width: double.infinity,
  height: 58,
  child: ElevatedButton(
    onPressed: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RecommendedHospitalsPage(),
        ),
      );
    },

    style: ElevatedButton.styleFrom(
      backgroundColor: teal,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),

    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Continue',
          style: TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(width: 8),
        Icon(
          Icons.arrow_forward_rounded,
          size: 20,
        ),
      ],
    ),
          ), // ElevatedButton
        ), // SizedBox
      ],
    ), // Column
  ), // ConstrainedBox
), // Center
), // SingleChildScrollView
), // SafeArea
); // Scaffold
}

  // QUESTION CONTAINER
  Widget _questionCard({
    required String number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5EEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFE4F7F6),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: darkTeal,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: darkTeal,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontFamily: 'Helvetica',
                        fontSize: 13,
                        height: 1.3,
                        color: grey,
                      ),
                    ),
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

  // NORMAL SINGLE-SELECT OPTION
  Widget _option({
    required String text,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        width: 135,
        height: 90,

        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),

        decoration: BoxDecoration(
          color: selected
              ? teal.withValues(alpha: 0.08)
              : optionBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? teal
                : const Color(0xFFE2EAEA),
            width: selected ? 1.5 : 1,
          ),
        ),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 27,
              color: selected ? teal : darkTeal,
            ),

            const SizedBox(height: 7),

            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Helvetica',
                fontSize: 13,
                height: 1.15,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w500,
                color: darkTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // MULTI-SELECT DANGER SIGN OPTION
  Widget _dangerOption({
    required String text,
    required IconData icon,
  }) {
    final bool selected = selectedDangerSigns.contains(text);

    return InkWell(
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

      borderRadius: BorderRadius.circular(14),

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),

        width: 135,
        height: 96,

        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),

        decoration: BoxDecoration(
          color: selected
              ? teal.withValues(alpha: 0.08)
              : optionBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? teal
                : const Color(0xFFE2EAEA),
            width: selected ? 1.5 : 1,
          ),
        ),

        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 27,
                    color: selected ? teal : darkTeal,
                  ),

                  const SizedBox(height: 7),

                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Helvetica',
                      fontSize: 13,
                      height: 1.15,
                      fontWeight: selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: darkTeal,
                    ),
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
                  color: teal,
                  size: 19,
                ),
              ),
          ],
        ),
      ),
    );
  }
}