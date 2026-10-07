import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared flag: becomes true once the user has saved a complete profile.
/// The home page listens to this to hide the "Complete your medical profile" card.
final ValueNotifier<bool> profileCompleted = ValueNotifier<bool>(false);

/// Latest saved profile details, read by the triage report.
final ValueNotifier<Map<String, String>> profileData =
    ValueNotifier<Map<String, String>>({
  'name': 'Aisyah Binti Ahmad',
  'age': '24',
  'sex': 'Female',
  'blood': 'O+',
  'allergies': 'Penicillin',
  'medication': 'None',
  'chronic': 'Asthma',
});

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isEditing = false;

  final fullNameController = TextEditingController(text: 'Aisyah Binti Ahmad');
  final icController = TextEditingController(text: '000101-00-0000');
  final ageController = TextEditingController(text: '24');
  final bloodTypeController = TextEditingController(text: 'O+');
  final allergiesController = TextEditingController(text: 'Penicillin');
  final medicationController = TextEditingController(text: 'None');
  final chronicConditionController = TextEditingController(text: 'Asthma');
  final surgeriesController =
      TextEditingController(text: 'Appendectomy, 2020');
  final pregnancyController = TextEditingController(text: 'Not applicable');
  final languageController = TextEditingController(text: 'English');
  final emergencyNameController =
      TextEditingController(text: 'Ahmad Bin Rahman');
  final emergencyNumberController =
      TextEditingController(text: '+60 12-345 6789');
  final relationshipController = TextEditingController(text: 'Father');

  String selectedSex = 'Female';

  @override
  void dispose() {
    fullNameController.dispose();
    icController.dispose();
    ageController.dispose();
    bloodTypeController.dispose();
    allergiesController.dispose();
    medicationController.dispose();
    chronicConditionController.dispose();
    surgeriesController.dispose();
    pregnancyController.dispose();
    languageController.dispose();
    emergencyNameController.dispose();
    emergencyNumberController.dispose();
    relationshipController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const BrandWordmark(),
                          _editButton(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    // PROFILE TOP
                    FadeSlideIn(
                      index: 1,
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.teal
                                        .withValues(alpha: 0.20),
                                    blurRadius: 30,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 46,
                                color: AppColors.darkTeal,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text('User Profile', style: AppText.display),
                            const SizedBox(height: 4),
                            Text(
                              'Personal and medical information',
                              style: AppText.body,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // PERSONAL
                    FadeSlideIn(
                      index: 2,
                      child: _section(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Information',
                        children: [
                          _editableRow(
                            label: 'Full Name',
                            controller: fullNameController,
                          ),
                          _divider(),
                          _editableRow(
                            label: 'IC Number',
                            controller: icController,
                          ),
                          _divider(),
                          _sexRow(),
                          _divider(),
                          _editableRow(
                            label: 'Age',
                            controller: ageController,
                            keyboardType: TextInputType.number,
                            suffix: 'years old',
                          ),
                          _divider(),
                          _editableRow(
                            label: 'Blood Type',
                            controller: bloodTypeController,
                          ),
                          _divider(),
                          _editableRow(
                            label: 'Preferred Language',
                            controller: languageController,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // MEDICAL
                    FadeSlideIn(
                      index: 3,
                      child: _section(
                        icon: Icons.medical_information_outlined,
                        title: 'Medical Information',
                        children: [
                          _editableRow(
                            label: 'Allergies',
                            controller: allergiesController,
                          ),
                          _divider(),
                          _editableRow(
                            label: 'Current Medication',
                            controller: medicationController,
                          ),
                          _divider(),
                          _editableRow(
                            label: 'Chronic Medical Conditions',
                            controller: chronicConditionController,
                          ),
                          _divider(),
                          _editableRow(
                            label: 'Previous Major Surgeries',
                            controller: surgeriesController,
                          ),
                          _divider(),
                          _editableRow(
                            label: 'Pregnancy Status',
                            controller: pregnancyController,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // EMERGENCY CONTACT
                    FadeSlideIn(
                      index: 4,
                      child: _section(
                        icon: Icons.contact_phone_outlined,
                        title: 'Emergency Contact',
                        children: [
                          _editableRow(
                            label: 'Contact Name',
                            controller: emergencyNameController,
                          ),
                          _divider(),
                          _editableRow(
                            label: 'Relationship',
                            controller: relationshipController,
                          ),
                          _divider(),
                          _editableRow(
                            label: 'Contact Number',
                            controller: emergencyNumberController,
                            keyboardType: TextInputType.phone,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lock_outline_rounded,
                            size: 20,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your medical information is sensitive. '
                              'Only information necessary for screening and care should be stored and used.',
                              style: AppText.caption,
                            ),
                          ),
                        ],
                      ),
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
  // EDIT / SAVE BUTTON
  // ============================================================

  Widget _editButton() {
    return Pressable(
      onTap: () {
        setState(() {
          isEditing = !isEditing;
        });

        if (!isEditing) {
          final complete = [
            fullNameController,
            icController,
            ageController,
            bloodTypeController,
            allergiesController,
            medicationController,
            chronicConditionController,
            surgeriesController,
            pregnancyController,
            languageController,
            emergencyNameController,
            emergencyNumberController,
            relationshipController,
          ].every((c) => c.text.trim().isNotEmpty);

          profileCompleted.value = complete;
          profileData.value = {
            'name': fullNameController.text.trim(),
            'age': ageController.text.trim(),
            'sex': selectedSex,
            'blood': bloodTypeController.text.trim(),
            'allergies': allergiesController.text.trim(),
            'medication': medicationController.text.trim(),
            'chronic': chronicConditionController.text.trim(),
          };

          showAppSnack(
            context,
            complete
                ? 'Profile updated.'
                : 'Profile saved. Some fields are still empty.',
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isEditing ? AppColors.darkTeal : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isEditing ? Icons.check_rounded : Icons.edit_outlined,
              color: isEditing ? Colors.white : AppColors.darkTeal,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              isEditing ? 'Save' : 'Edit',
              style: AppText.style(
                14,
                FontWeight.w700,
                isEditing ? Colors.white : AppColors.darkTeal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ROWS
  // ============================================================

  Widget _editableRow({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? suffix,
  }) {
    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(label, style: AppText.caption),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Text(
                suffix == null
                    ? controller.text
                    : '${controller.text} $suffix',
                textAlign: TextAlign.right,
                style: AppText.bodyStrong,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 7),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppText.input,
            decoration: _fieldDecoration(suffix: suffix),
          ),
        ],
      ),
    );
  }

  Widget _sexRow() {
    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(flex: 4, child: Text('Sex', style: AppText.caption)),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: Text(
                selectedSex,
                textAlign: TextAlign.right,
                style: AppText.bodyStrong,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sex', style: AppText.label),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            initialValue: selectedSex,
            style: AppText.input,
            borderRadius: BorderRadius.circular(16),
            items: const [
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Male', child: Text('Male')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedSex = value;
                });
              }
            },
            decoration: _fieldDecoration(),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration({String? suffix}) {
    return InputDecoration(
      suffixText: suffix,
      suffixStyle: AppText.caption,
      filled: true,
      fillColor: AppColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
    );
  }

  // ============================================================
  // SECTIONS
  // ============================================================

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.paleTeal,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 18, color: AppColors.teal),
            ),
            const SizedBox(width: 10),
            Text(title, style: AppText.heading),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: cardDecoration(radius: 24),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _divider() {
    return const Divider(height: 1, color: AppColors.border);
  }
}