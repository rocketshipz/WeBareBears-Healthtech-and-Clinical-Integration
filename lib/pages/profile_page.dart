import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const Color teal = Color(0xFF3BB8C1);
  static const Color darkTeal = Color(0xFF0D5C63);
  static const Color grey = Color(0xFF7A8C8D);
  static const Color background = Color(0xFFF7FBFB);
  static const Color lightTeal = Color(0xFFE4F7F6);
  static const Color border = Color(0xFFE3ECEC);

  bool isEditing = false;

  final fullNameController =
      TextEditingController(text: 'Aisyah Binti Ahmad');

  final icController =
      TextEditingController(text: '000101-00-0000');

  final ageController =
      TextEditingController(text: '24');

  final bloodTypeController =
      TextEditingController(text: 'O+');

  final allergiesController =
      TextEditingController(text: 'Penicillin');

  final medicationController =
      TextEditingController(text: 'None');

  final chronicConditionController =
      TextEditingController(text: 'Asthma');

  final surgeriesController =
      TextEditingController(text: 'Appendectomy, 2020');

  final pregnancyController =
      TextEditingController(text: 'Not applicable');

  final languageController =
      TextEditingController(text: 'English');

  final emergencyNameController =
      TextEditingController(text: 'Ahmad Bin Rahman');

  final emergencyNumberController =
      TextEditingController(text: '+60 12-345 6789');

  final relationshipController =
      TextEditingController(text: 'Father');

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
      backgroundColor: background,

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),

          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 600,
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 23,
                            fontWeight: FontWeight.w700,
                          ),
                          children: [
                            TextSpan(
                              text: 'Triage',
                              style: TextStyle(
                                color: darkTeal,
                              ),
                            ),
                            TextSpan(
                              text: 'MY',
                              style: TextStyle(
                                color: teal,
                              ),
                            ),
                          ],
                        ),
                      ),

                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            isEditing = !isEditing;
                          });

                          if (!isEditing) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Profile updated.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          isEditing
                              ? Icons.check_rounded
                              : Icons.edit_outlined,
                          color: darkTeal,
                          size: 20,
                        ),
                        label: Text(
                          isEditing ? 'Save' : 'Edit',
                          style: const TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: darkTeal,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // PROFILE TOP
                  const Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 42,
                          backgroundColor: lightTeal,
                          child: Icon(
                            Icons.person_rounded,
                            size: 46,
                            color: darkTeal,
                          ),
                        ),

                        SizedBox(height: 12),

                        Text(
                          'User Profile',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: darkTeal,
                          ),
                        ),

                        SizedBox(height: 5),

                        Text(
                          'Personal and medical information',
                          style: TextStyle(
                            fontFamily: 'Helvetica',
                            fontSize: 13,
                            color: grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // PERSONAL
                  _sectionTitle(
                    icon: Icons.person_outline_rounded,
                    title: 'Personal Information',
                  ),

                  const SizedBox(height: 12),

                  _sectionCard(
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

                  const SizedBox(height: 28),

                  // MEDICAL
                  _sectionTitle(
                    icon: Icons.medical_information_outlined,
                    title: 'Medical Information',
                  ),

                  const SizedBox(height: 12),

                  _sectionCard(
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

                  const SizedBox(height: 28),

                  // EMERGENCY CONTACT
                  _sectionTitle(
                    icon: Icons.contact_phone_outlined,
                    title: 'Emergency Contact',
                  ),

                  const SizedBox(height: 12),

                  _sectionCard(
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

                  const SizedBox(height: 26),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: lightTeal,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 20,
                          color: darkTeal,
                        ),

                        SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            'Your medical information is sensitive. '
                            'Only information necessary for screening and care should be stored and used.',
                            style: TextStyle(
                              fontFamily: 'Helvetica',
                              fontSize: 12,
                              height: 1.4,
                              color: darkTeal,
                            ),
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
    );
  }

  Widget _editableRow({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? suffix,
  }) {
    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 12,
                  color: grey,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              flex: 5,
              child: Text(
                suffix == null
                    ? controller.text
                    : '${controller.text} $suffix',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: darkTeal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: darkTeal,
            ),
          ),

          const SizedBox(height: 7),

          TextField(
            controller: controller,
            keyboardType: keyboardType,

            decoration: InputDecoration(
              suffixText: suffix,
              filled: true,
              fillColor:
                  const Color(0xFFF3F7F7),

              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),

              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(13),
                borderSide:
                    const BorderSide(
                  color: teal,
                  width: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sexRow() {
    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 14,
        ),

        child: Row(
          children: [
            const Expanded(
              flex: 4,
              child: Text(
                'Sex',
                style: TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 12,
                  color: grey,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              flex: 5,
              child: Text(
                selectedSex,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontFamily: 'Helvetica',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: darkTeal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Sex',
            style: TextStyle(
              fontFamily: 'Helvetica',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: darkTeal,
            ),
          ),

          const SizedBox(height: 7),

          DropdownButtonFormField<String>(
            initialValue: selectedSex,

            items: const [
              DropdownMenuItem(
                value: 'Female',
                child: Text('Female'),
              ),
              DropdownMenuItem(
                value: 'Male',
                child: Text('Male'),
              ),
            ],

            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedSex = value;
                });
              }
            },

            decoration: InputDecoration(
              filled: true,
              fillColor:
                  const Color(0xFFF3F7F7),

              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),

              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(13),
                borderSide:
                    const BorderSide(
                  color: teal,
                  width: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: darkTeal,
        ),

        const SizedBox(width: 8),

        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Helvetica',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: darkTeal,
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: border,
        ),
      ),

      child: Column(
        children: children,
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      color: border,
    );
  }
}