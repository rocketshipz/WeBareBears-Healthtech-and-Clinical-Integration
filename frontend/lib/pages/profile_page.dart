import '../localization.dart';

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/visit_history.dart';
import '../services/auth_service.dart';
import '../screens/role_selection_screen.dart';

/// Shared flag used by the home page.
final ValueNotifier<bool> profileCompleted = ValueNotifier<bool>(false);

/// Latest saved profile details used by other prototype pages.
final ValueNotifier<Map<String, String>> profileData =
    ValueNotifier<Map<String, String>>({
      'name': 'Aisyah Binti Ahmad',
      'age': '24',
      'dateOfBirth': '2002-01-01',
      'sex': 'Female',
      'blood': 'O+',
      'allergies': 'Medication',
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
  bool _saving = false;
  bool _loading = false;
  bool _profileLoaded = false;

  // ============================================================
  // TEXT CONTROLLERS
  // ============================================================

  final sexController = TextEditingController();
  final fullNameController = TextEditingController(text: 'Aisyah Binti Ahmad');

  final icController = TextEditingController(text: '020101-08-1234');

  final dateOfBirthController = TextEditingController(text: '2002-01-01');

  final ageController = TextEditingController(text: '24');

  final heightController = TextEditingController(text: '160');

  final weightController = TextEditingController(text: '55');

  final emergencyNameController = TextEditingController(
    text: 'Ahmad Bin Rahman',
  );

  final emergencyNumberController = TextEditingController(
    text: '+60 12-345 6789',
  );

  final nationalityController = TextEditingController();
  final languageOtherController = TextEditingController();
  final relationshipOtherController = TextEditingController();

  // ============================================================
  // SINGLE-SELECT VALUES
  // ============================================================

  String selectedSex = 'Female';
  String selectedNationality = 'Malaysia';
  String selectedLanguage = 'English';
  String selectedBloodType = 'O+';

  String selectedSmokingStatus = 'Never';
  String selectedAlcoholUse = 'None';

  String selectedRelationship = 'Father';
  String selectedOrganDonor = 'No';

  bool locationConsent = true;

  // ============================================================
  // MULTI-SELECT VALUES
  // ============================================================

  final List<String> selectedChronicConditions = ['Asthma'];

  final allergiesController = TextEditingController();
  final conditionController = TextEditingController();
  final List<String> selectedAllergies = (profileData.value['allergies'] ?? '')
      .split(',')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toList();

  final List<String> selectedMedications = ['None'];

  final List<String> selectedSurgeries = ['Appendectomy'];

  final List<String> selectedFamilyHistory = ['Diabetes'];

  // Custom items added by user
  final List<String> customChronicConditions = [];
  final List<String> customMedications = [];
  final List<String> customSurgeries = [];
  final List<String> customFamilyHistory = [];

  // ============================================================
  // OPTIONS
  // ============================================================

  final List<String> languageOptions = [
    'English',
    'Bahasa Melayu',
    'Mandarin',
    'Tamil',
    'Other',
  ];

  final List<String> bloodTypeOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unsure',
  ];

  final List<String> chronicConditionOptions = [
    'Asthma',
    'Diabetes',
    'Hypertension',
    'Heart disease',
    'Epilepsy',
    'Kidney disease',
    'None',
  ];

  final List<String> medicationOptions = [
    'Painkillers',
    'Antibiotics',
    'Blood pressure medication',
    'Diabetes medication',
    'Asthma medication',
    'None',
  ];

  final List<String> surgeryOptions = [
    'Appendectomy',
    'Caesarean section',
    'Gallbladder surgery',
    'Heart surgery',
    'Orthopaedic surgery',
    'None',
  ];

  final List<String> familyHistoryOptions = [
    'Diabetes',
    'Hypertension',
    'Heart disease',
    'Stroke',
    'Cancer',
    'Asthma',
    'Kidney disease',
    'None',
    'Unknown',
  ];

  final List<String> smokingOptions = ['Never', 'Former', 'Current'];

  final List<String> alcoholOptions = ['None', 'Occasional', 'Regular'];

  final List<String> relationshipOptions = [
    'Mother',
    'Father',
    'Child',
    'Spouse',
    'Sibling',
    'Guardian',
    'Relative',
    'Friend',
    'Other',
  ];

  final List<String> organDonorOptions = ['Yes', 'No'];

  // ============================================================
  // INITIAL SETUP
  // ============================================================

  @override
  void initState() {
    super.initState();
    final user = AuthService.currentUser;
    if (user != null) {
      fullNameController.text = user['name']?.toString() ?? '';
      icController.text = user['ic']?.toString() ?? '';
      selectedNationality = user['nationality']?.toString() ?? 'Not specified';
      final birthDate = user['date_of_birth']?.toString();
      if (birthDate != null) dateOfBirthController.text = birthDate;
      final sex = user['sex_at_birth']?.toString() ?? '';
      selectedSex = sex.isEmpty
          ? 'Not specified'
          : '${sex[0].toUpperCase()}${sex.substring(1)}';
      profileData.value = {
        ...profileData.value,
        'name': fullNameController.text,
        'sex': selectedSex,
      };
    }
    if (AuthService.isAuthenticated) _loadProfile();
    sexController.text = selectedSex;
    nationalityController.text = selectedNationality;

    icController.addListener(_updateDetailsFromIc);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDetailsFromIc();
    });
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final data = await AuthService.loadProfile();
      if (!mounted) return;
      setState(() {
        String text(String key) => data[key]?.toString() ?? '';
        String title(String key, String fallback) {
          final value = text(key);
          return value.isEmpty
              ? fallback
              : '${value[0].toUpperCase()}${value.substring(1)}';
        }

        void items(List<String> target, String key, [String? property]) {
          target
            ..clear()
            ..addAll(
              (data[key] as List? ?? [])
                  .map(
                    (item) => property == null
                        ? item.toString()
                        : (item[property] ?? '').toString(),
                  )
                  .where((value) => value.isNotEmpty),
            );
        }

        fullNameController.text = text('name');
        icController.text = text('ic');
        dateOfBirthController.text = text('date_of_birth');
        ageController.text = text('age');
        selectedSex = title('sex_at_birth', 'Not specified');
        sexController.text = selectedSex;
        selectedNationality = text('nationality');
        nationalityController.text = selectedNationality;
        selectedLanguage = languageOptions.contains(text('preferred_language'))
            ? text('preferred_language')
            : 'Other';
        languageOtherController.text = selectedLanguage == 'Other'
            ? text('preferred_language')
            : '';
        heightController.text = text('height_cm');
        weightController.text = text('weight_kg');
        selectedBloodType = bloodTypeOptions.contains(text('blood_type'))
            ? text('blood_type')
            : 'Unsure';
        items(selectedChronicConditions, 'chronic_conditions', 'name');
        items(selectedMedications, 'current_medications', 'name');
        items(selectedSurgeries, 'past_surgeries');
        items(selectedFamilyHistory, 'family_history');
        void custom(
          List<String> target,
          List<String> selected,
          List<String> options,
        ) {
          target
            ..clear()
            ..addAll(selected.where((value) => !options.contains(value)));
        }

        custom(
          customChronicConditions,
          selectedChronicConditions,
          chronicConditionOptions,
        );
        custom(customMedications, selectedMedications, medicationOptions);
        custom(customSurgeries, selectedSurgeries, surgeryOptions);
        custom(
          customFamilyHistory,
          selectedFamilyHistory,
          familyHistoryOptions,
        );
        items(selectedAllergies, 'allergies', 'substance');
        selectedSmokingStatus = title('smoking_status', 'Never');
        selectedAlcoholUse = title('alcohol_use', 'None');
        emergencyNameController.text = text('emergency_contact_name');
        emergencyNumberController.text = text('emergency_contact_phone');
        selectedRelationship =
            relationshipOptions.contains(text('emergency_contact_relation'))
            ? text('emergency_contact_relation')
            : 'Other';
        relationshipOtherController.text = selectedRelationship == 'Other'
            ? text('emergency_contact_relation')
            : '';
        selectedOrganDonor = data['organ_donor'] == true ? 'Yes' : 'No';
        locationConsent = data['location_consent'] == true;
        _profileLoaded = true;
      });
      profileCompleted.value = _isProfileComplete;
      profileData.value = {
        ...profileData.value,
        'name': fullNameController.text,
        'sex': selectedSex,
        'age': ageController.text,
        'dateOfBirth': dateOfBirthController.text,
        'blood': selectedBloodType,
        'allergies': selectedAllergies.join(', '),
        'chronic': selectedChronicConditions.join(', '),
        'medication': selectedMedications.join(', '),
      };
    } on AuthException catch (error) {
      if (mounted) showAppSnack(context, error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ============================================================
  // IC -> DOB + AGE
  // ============================================================

  void _updateDetailsFromIc() {
    if (selectedNationality != 'Malaysia') {
      final dob = DateTime.tryParse(dateOfBirthController.text);
      if (dob != null) {
        final now = DateTime.now();
        ageController.text =
            (now.year -
                    dob.year -
                    ((now.month < dob.month ||
                            (now.month == dob.month && now.day < dob.day))
                        ? 1
                        : 0))
                .toString();
      }
      return;
    }
    final cleanedIc = icController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanedIc.length < 6) {
      return;
    }

    final birthPart = cleanedIc.substring(0, 6);

    final yy = int.tryParse(birthPart.substring(0, 2));

    final mm = int.tryParse(birthPart.substring(2, 4));

    final dd = int.tryParse(birthPart.substring(4, 6));

    if (yy == null || mm == null || dd == null) {
      return;
    }

    final now = DateTime.now();

    final currentTwoDigitYear = now.year % 100;

    final fullYear = yy > currentTwoDigitYear ? 1900 + yy : 2000 + yy;

    try {
      final dob = DateTime(fullYear, mm, dd);

      // Check whether the generated date actually matches.
      // Example: prevents invalid 31/02.
      if (dob.year != fullYear || dob.month != mm || dob.day != dd) {
        return;
      }

      int age = now.year - dob.year;

      final birthdayPassed =
          now.month > dob.month ||
          (now.month == dob.month && now.day >= dob.day);

      if (!birthdayPassed) {
        age--;
      }

      final dobString =
          '${dob.year.toString().padLeft(4, '0')}-'
          '${dob.month.toString().padLeft(2, '0')}-'
          '${dob.day.toString().padLeft(2, '0')}';

      if (dateOfBirthController.text != dobString) {
        dateOfBirthController.text = dobString;
      }

      if (ageController.text != age.toString()) {
        ageController.text = age.toString();
      }

      if (mounted) {
        setState(() {});
      }
    } catch (_) {
      // Ignore invalid IC DOB.
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    icController.removeListener(_updateDetailsFromIc);

    conditionController.dispose();
    allergiesController.dispose();
    sexController.dispose();
    fullNameController.dispose();
    icController.dispose();
    dateOfBirthController.dispose();
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();

    emergencyNameController.dispose();
    emergencyNumberController.dispose();

    nationalityController.dispose();
    languageOtherController.dispose();
    relationshipOtherController.dispose();

    super.dispose();
  }

  // ============================================================
  // PAGE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _languageDropdown(),
                              const SizedBox(width: 8),
                              _editButton(),
                            ],
                          ),
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
                                    color: AppColors.teal.withValues(
                                      alpha: 0.20,
                                    ),
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

                            LocalizedText(
                              'User Profile',
                              style: AppText.display,
                            ),

                            const SizedBox(height: 4),

                            LocalizedText(
                              'Personal and medical information',
                              style: AppText.body,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // ========================================================
                    // PERSONAL
                    // ========================================================
                    FadeSlideIn(
                      index: 2,
                      child: _section(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Information',
                        children: [
                          _editableRow(
                            label: 'Full Name',
                            readOnly: true,
                            controller: fullNameController,
                          ),

                          _divider(),

                          _editableRow(
                            label: 'IC Number',
                            readOnly: true,
                            controller: icController,
                            keyboardType: TextInputType.number,
                          ),

                          _divider(),

                          _readOnlyCalculatedRow(
                            label: 'Date of Birth',
                            controller: dateOfBirthController,
                          ),

                          _divider(),

                          _readOnlyCalculatedRow(
                            label: 'Age',
                            controller: ageController,
                            suffix: 'years old',
                          ),

                          _divider(),

                          _editableRow(
                            label: 'Sex at Birth',
                            controller: sexController,
                            readOnly: true,
                          ),

                          _divider(),

                          _editableRow(
                            label: 'Nationality',
                            controller: nationalityController,
                            readOnly: true,
                          ),

                          _divider(),

                          _dropdownRow(
                            label: 'Preferred Language',
                            value: selectedLanguage,
                            options: languageOptions,
                            onChanged: (value) {
                              setState(() {
                                selectedLanguage = value;
                              });
                            },
                            otherController: languageOtherController,
                          ),

                          _divider(),

                          _editableRow(
                            label: 'Height',
                            controller: heightController,
                            keyboardType: TextInputType.number,
                            suffix: 'cm',
                          ),

                          _divider(),

                          _editableRow(
                            label: 'Weight',
                            controller: weightController,
                            keyboardType: TextInputType.number,
                            suffix: 'kg',
                          ),

                          _divider(),

                          _dropdownRow(
                            label: 'Blood Type',
                            value: selectedBloodType,
                            options: bloodTypeOptions,
                            onChanged: (value) {
                              setState(() {
                                selectedBloodType = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ========================================================
                    // MEDICAL
                    // ========================================================
                    FadeSlideIn(
                      index: 3,
                      child: _section(
                        icon: Icons.medical_information_outlined,
                        title: 'Medical Information',
                        children: [
                          _multipleTextRow(
                            label: 'Chronic Conditions',
                            values: selectedChronicConditions,
                            controller: conditionController,
                            hint: 'Add another condition',
                          ),

                          _divider(),

                          _multipleTextRow(
                            label: 'Allergies',
                            values: selectedAllergies,
                            controller: allergiesController,
                            hint: 'Add another allergy',
                          ),

                          _divider(),

                          _multiSelectRow(
                            label: 'Current Medications',
                            selectedValues: selectedMedications,
                            predefinedOptions: medicationOptions,
                            customValues: customMedications,
                            addHint: 'Add another medication',
                            exclusiveValues: const ['None'],
                          ),

                          _divider(),

                          _multiSelectRow(
                            label: 'Past Surgeries',
                            selectedValues: selectedSurgeries,
                            predefinedOptions: surgeryOptions,
                            customValues: customSurgeries,
                            addHint: 'Add another surgery',
                            exclusiveValues: const ['None'],
                          ),

                          _divider(),

                          _multiSelectRow(
                            label: 'Family History',
                            selectedValues: selectedFamilyHistory,
                            predefinedOptions: familyHistoryOptions,
                            customValues: customFamilyHistory,
                            addHint: 'Add another condition',
                            exclusiveValues: const ['None', 'Unknown'],
                          ),

                          _divider(),

                          _dropdownRow(
                            label: 'Smoking Status',
                            value: selectedSmokingStatus,
                            options: smokingOptions,
                            onChanged: (value) {
                              setState(() {
                                selectedSmokingStatus = value;
                              });
                            },
                          ),

                          _divider(),

                          _dropdownRow(
                            label: 'Alcohol Use',
                            value: selectedAlcoholUse,
                            options: alcoholOptions,
                            onChanged: (value) {
                              setState(() {
                                selectedAlcoholUse = value;
                              });
                            },
                          ),

                          _divider(),

                          _dropdownRow(
                            label: 'Organ Donor',
                            value: selectedOrganDonor,
                            options: organDonorOptions,
                            onChanged: (value) {
                              setState(() {
                                selectedOrganDonor = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    // ========================================================
                    // EMERGENCY CONTACT
                    // ========================================================
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

                          _dropdownRow(
                            label: 'Relationship',
                            value: selectedRelationship,
                            options: relationshipOptions,
                            onChanged: (value) {
                              setState(() {
                                selectedRelationship = value;
                              });
                            },
                            otherController: relationshipOtherController,
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

                    const SizedBox(height: 26),

                    const VisitHistory(),
                    const SizedBox(height: 26),

                    // ========================================================
                    // PERMISSIONS
                    // ========================================================
                    FadeSlideIn(
                      index: 5,
                      child: _section(
                        icon: Icons.location_on_outlined,
                        title: 'Permissions',
                        children: [_locationConsentRow()],
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
                            child: LocalizedText(
                              'Your medical information is sensitive. '
                              'Only information necessary for screening and care should be stored and used.',
                              style: AppText.caption,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    PrimaryButton(
                      label: 'Log out',
                      icon: Icons.logout_rounded,
                      color: AppColors.red,
                      onPressed: _saving
                          ? null
                          : () {
                              AuthService.logout();
                              profileData.value = {};
                              profileCompleted.value = false;
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute<void>(
                                  builder: (_) => const RoleSelectionScreen(),
                                ),
                                (route) => false,
                              );
                            },
                    ),
                    const SizedBox(height: 24),
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
  // EDIT / SAVE
  // ============================================================

  Widget _languageDropdown() {
    return ValueListenableBuilder<Locale>(
      valueListenable: AppLanguage.instance,
      builder: (context, locale, child) => Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            key: const ValueKey('profile-language'),
            value: locale.languageCode,
            isDense: true,
            borderRadius: BorderRadius.circular(14),
            icon: const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.darkTeal,
            ),
            style: AppText.bodyStrong,
            selectedItemBuilder: (context) => const [
              Center(child: Text('EN')),
              Center(child: Text('BM')),
            ],
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'ms', child: Text('Bahasa Melayu')),
            ],
            onChanged: (value) {
              if (value != null) AppLanguage.instance.select(value);
            },
          ),
        ),
      ),
    );
  }

  Widget _editButton() {
    return Pressable(
      onTap: _saving || _loading
          ? null
          : () async {
              if (AuthService.isAuthenticated && !_profileLoaded) {
                await _loadProfile();
                return;
              }
              if (isEditing) {
                await _saveProfile();
              } else {
                setState(() => isEditing = true);
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

            LocalizedText(
              _saving
                  ? 'Saving...'
                  : _loading
                  ? 'Loading...'
                  : isEditing
                  ? 'Save'
                  : 'Edit',
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
  // SAVE
  // ============================================================

  bool get _isProfileComplete => [
    fullNameController.text.trim(),
    icController.text.trim(),
    dateOfBirthController.text.trim(),
    ageController.text.trim(),
    heightController.text.trim(),
    weightController.text.trim(),
    emergencyNameController.text.trim(),
    emergencyNumberController.text.trim(),
  ].every((value) => value.isNotEmpty);

  Future<void> _saveProfile() async {
    if (_saving) return;
    _commitEntries(selectedChronicConditions, conditionController);
    _commitEntries(selectedAllergies, allergiesController);
    final height = heightController.text.trim();
    final weight = weightController.text.trim();
    if ((height.isNotEmpty &&
            (double.tryParse(height) == null ||
                !double.parse(height).isFinite ||
                double.parse(height) <= 0)) ||
        (weight.isNotEmpty &&
            (double.tryParse(weight) == null ||
                !double.parse(weight).isFinite ||
                double.parse(weight) <= 0))) {
      showAppSnack(context, 'Please enter a valid height and weight.');
      return;
    }
    final complete = _isProfileComplete;

    final savedProfile = <String, String>{
      'name': fullNameController.text.trim(),

      'age': ageController.text.trim(),

      'dateOfBirth': dateOfBirthController.text.trim(),

      'sex': selectedSex,

      'nationality': selectedNationality,

      'language': _resolvedValue(selectedLanguage, languageOtherController),

      'height': heightController.text.trim(),

      'weight': weightController.text.trim(),

      'blood': selectedBloodType,

      'chronic': selectedChronicConditions.join(', '),

      'allergies': selectedAllergies.join(', '),

      'medication': selectedMedications.join(', '),

      'surgeries': selectedSurgeries.join(', '),

      'familyHistory': selectedFamilyHistory.join(', '),

      'smoking': selectedSmokingStatus,

      'alcohol': selectedAlcoholUse,

      'emergencyName': emergencyNameController.text.trim(),

      'emergencyPhone': emergencyNumberController.text.trim(),

      'emergencyRelationship': _resolvedValue(
        selectedRelationship,
        relationshipOtherController,
      ),

      'organDonor': selectedOrganDonor,

      'locationConsent': locationConsent ? 'Yes' : 'No',
    };

    setState(() => _saving = true);
    try {
      await AuthService.saveProfile({
        'preferred_language': savedProfile['language'],
        'height_cm': height.isEmpty ? null : double.parse(height),
        'weight_kg': weight.isEmpty ? null : double.parse(weight),
        'blood_type': selectedBloodType == 'Unsure'
            ? 'unknown'
            : selectedBloodType,
        'chronic_conditions': selectedChronicConditions
            .map((name) => {'name': name})
            .toList(),
        'allergies': selectedAllergies
            .map((substance) => {'substance': substance})
            .toList(),
        'current_medications': selectedMedications
            .map((name) => {'name': name})
            .toList(),
        'past_surgeries': selectedSurgeries.toList(),
        'family_history': selectedFamilyHistory.toList(),
        'smoking_status': selectedSmokingStatus.toLowerCase(),
        'alcohol_use': selectedAlcoholUse.toLowerCase(),
        'emergency_contact_name': emergencyNameController.text.trim(),
        'emergency_contact_phone': emergencyNumberController.text.trim(),
        'emergency_contact_relation': savedProfile['emergencyRelationship'],
        'organ_donor': selectedOrganDonor == 'Yes',
        'location_consent': locationConsent,
      });
      if (!mounted) return;
      profileData.value = savedProfile;
      profileCompleted.value = complete;
      setState(() => isEditing = false);
    } on AuthException catch (error) {
      if (mounted) showAppSnack(context, error.message);
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    showAppSnack(
      context,
      complete
          ? 'Profile updated.'
          : 'Profile saved. Some fields are still empty.',
    );
  }

  String _resolvedValue(
    String selected,
    TextEditingController otherController,
  ) {
    if (selected == 'Other') {
      final custom = otherController.text.trim();

      if (custom.isNotEmpty) {
        return custom;
      }
    }

    return selected;
  }

  // ============================================================
  // NORMAL EDITABLE ROW
  // ============================================================

  Widget _editableRow({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    String? suffix,
  }) {
    if (!isEditing || readOnly) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: LocalizedText(label, style: AppText.caption),
            ),

            const SizedBox(width: 12),

            Expanded(
              flex: 5,
              child: LocalizedText(
                suffix == null ? controller.text : '${controller.text} $suffix',
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
          LocalizedText(label, style: AppText.label),

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

  // ============================================================
  // READ-ONLY CALCULATED FIELD
  // ============================================================

  Widget _readOnlyCalculatedRow({
    required String label,
    required TextEditingController controller,
    String? suffix,
  }) {
    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: LocalizedText(label, style: AppText.caption),
            ),

            const SizedBox(width: 12),

            Expanded(
              flex: 5,
              child: LocalizedText(
                controller.text.isEmpty
                    ? '-'
                    : suffix == null
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
          LocalizedText(label, style: AppText.label),

          const SizedBox(height: 7),

          TextField(
            controller: controller,
            readOnly: true,
            style: AppText.input,
            decoration: _fieldDecoration(suffix: suffix).copyWith(
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppColors.grey,
              ),
            ),
          ),

          const SizedBox(height: 5),

          LocalizedText(
            selectedNationality == 'Malaysia'
                ? 'Calculated automatically from IC number.'
                : 'Registered date of birth.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SINGLE DROPDOWN
  // ============================================================

  Widget _dropdownRow({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    TextEditingController? otherController,
  }) {
    final displayValue =
        value == 'Other' &&
            otherController != null &&
            otherController.text.trim().isNotEmpty
        ? otherController.text.trim()
        : value;

    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: LocalizedText(label, style: AppText.caption),
            ),

            const SizedBox(width: 12),

            Expanded(
              flex: 5,
              child: LocalizedText(
                displayValue,
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
          LocalizedText(label, style: AppText.label),

          const SizedBox(height: 7),

          DropdownButtonFormField<String>(
            initialValue: value,
            isExpanded: true,
            style: AppText.input,
            borderRadius: BorderRadius.circular(16),

            decoration: _fieldDecoration(),

            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: LocalizedText(option, overflow: TextOverflow.ellipsis),
              );
            }).toList(),

            onChanged: (newValue) {
              if (newValue != null) {
                onChanged(newValue);
              }
            },
          ),

          if (value == 'Other' && otherController != null) ...[
            const SizedBox(height: 10),

            TextField(
              controller: otherController,
              style: AppText.input,
              decoration: _fieldDecoration().copyWith(
                hintText: tr('Please specify'),
                hintStyle: AppText.caption,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _commitEntries(List<String> values, TextEditingController controller) {
    for (final entry in controller.text.split(RegExp(r'[,;\n]'))) {
      final value = entry.trim();
      if (value.isEmpty) continue;
      if (value.toLowerCase() == 'none' ||
          value.toLowerCase() == 'no known allergies') {
        values.clear();
      } else {
        values.removeWhere(
          (item) =>
              item.toLowerCase() == 'none' ||
              item.toLowerCase() == 'no known allergies',
        );
      }
      if (!values.any((item) => item.toLowerCase() == value.toLowerCase())) {
        values.add(value);
      }
    }
    controller.clear();
  }

  Widget _multipleTextRow({
    required String label,
    required List<String> values,
    required TextEditingController controller,
    required String hint,
  }) {
    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: LocalizedText(label, style: AppText.caption),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: LocalizedText(
                values.isEmpty ? 'None reported' : values.join(', '),
                style: AppText.bodyStrong,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(label, style: AppText.label),
          const SizedBox(height: 8),
          if (values.isEmpty && !isEditing)
            LocalizedText('None reported', style: AppText.bodyStrong),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: values
                .map(
                  (value) => InputChip(
                    label: LocalizedText(value),
                    onDeleted: isEditing
                        ? () => setState(() => values.remove(value))
                        : null,
                    backgroundColor: AppColors.paleTeal,
                  ),
                )
                .toList(),
          ),
          if (isEditing) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('entries-$label'),
                    controller: controller,
                    style: AppText.input,
                    decoration: _fieldDecoration().copyWith(hintText: tr(hint)),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        setState(() => _commitEntries(values, controller)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: tr('Add'),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.darkTeal,
                  ),
                  onPressed: () =>
                      setState(() => _commitEntries(values, controller)),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: 5),
            LocalizedText(
              'Add each item, then tap +. You can add more than one.',
              style: AppText.caption,
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // MULTI SELECT
  // ============================================================

  Widget _multiSelectRow({
    required String label,
    required List<String> selectedValues,
    required List<String> predefinedOptions,
    required List<String> customValues,
    required String addHint,
    List<String> exclusiveValues = const [],
  }) {
    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: LocalizedText(label, style: AppText.caption),
            ),

            const SizedBox(width: 12),

            Expanded(
              flex: 5,
              child: LocalizedText(
                selectedValues.isEmpty
                    ? 'None selected'
                    : selectedValues.join(', '),
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
          LocalizedText(label, style: AppText.label),

          const SizedBox(height: 7),

          Pressable(
            onTap: () {
              _showMultiSelectSheet(
                title: label,
                selectedValues: selectedValues,
                predefinedOptions: predefinedOptions,
                customValues: customValues,
                addHint: addHint,
                exclusiveValues: exclusiveValues,
              );
            },

            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: selectedValues.isEmpty
                        ? LocalizedText(
                            'Select one or more',
                            style: AppText.caption,
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedValues.map((item) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.paleTeal,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: LocalizedText(
                                  item,
                                  style: AppText.style(
                                    11,
                                    FontWeight.w600,
                                    AppColors.darkTeal,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                  ),

                  const SizedBox(width: 8),

                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.grey,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 5),

          LocalizedText(
            'You can select multiple options or add your own.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MULTI SELECT SHEET
  // ============================================================

  Future<void> _showMultiSelectSheet({
    required String title,
    required List<String> selectedValues,
    required List<String> predefinedOptions,
    required List<String> customValues,
    required String addHint,
    required List<String> exclusiveValues,
  }) async {
    final customController = TextEditingController();

    final workingSelection = List<String>.from(selectedValues);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final allOptions = [...predefinedOptions, ...customValues];

            void toggleOption(String option, bool checked) {
              setSheetState(() {
                if (checked) {
                  // If selecting an exclusive option,
                  // clear everything else.
                  if (exclusiveValues.contains(option)) {
                    workingSelection
                      ..clear()
                      ..add(option);
                  } else {
                    // Remove exclusive values such as None.
                    workingSelection.removeWhere(
                      (item) => exclusiveValues.contains(item),
                    );

                    if (!workingSelection.contains(option)) {
                      workingSelection.add(option);
                    }
                  }
                } else {
                  workingSelection.remove(option);
                }
              });
            }

            void addCustomValue() {
              final custom = customController.text.trim();

              if (custom.isEmpty) {
                return;
              }

              setSheetState(() {
                if (!customValues.contains(custom)) {
                  customValues.add(custom);
                }

                workingSelection.removeWhere(
                  (item) => exclusiveValues.contains(item),
                );

                if (!workingSelection.contains(custom)) {
                  workingSelection.add(custom);
                }

                customController.clear();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.82,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),

                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: LocalizedText(title, style: AppText.heading),
                          ),

                          IconButton(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1, color: AppColors.border),

                    Flexible(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        children: [
                          ...allOptions.map((option) {
                            final checked = workingSelection.contains(option);

                            final isCustom = customValues.contains(option);

                            return CheckboxListTile(
                              value: checked,
                              activeColor: AppColors.darkTeal,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              title: LocalizedText(
                                option,
                                style: AppText.bodyStrong,
                              ),
                              secondary: isCustom
                                  ? IconButton(
                                      tooltip: tr('Remove'),
                                      onPressed: () {
                                        setSheetState(() {
                                          customValues.remove(option);

                                          workingSelection.remove(option);
                                        });
                                      },
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.grey,
                                        size: 20,
                                      ),
                                    )
                                  : null,
                              onChanged: (value) {
                                toggleOption(option, value ?? false);
                              },
                            );
                          }),

                          const SizedBox(height: 12),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: LocalizedText(
                              'Add your own',
                              style: AppText.label,
                            ),
                          ),

                          const SizedBox(height: 7),

                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: customController,
                                    style: AppText.input,
                                    decoration: _fieldDecoration().copyWith(
                                      hintText: tr(addHint),
                                      hintStyle: AppText.caption,
                                    ),
                                    onSubmitted: (_) {
                                      addCustomValue();
                                    },
                                  ),
                                ),

                                const SizedBox(width: 8),

                                Pressable(
                                  onTap: addCustomValue,
                                  child: Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.darkTeal,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedValues
                                ..clear()
                                ..addAll(workingSelection);
                            });

                            Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.darkTeal,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: LocalizedText(
                            'Done',
                            style: AppText.style(
                              14,
                              FontWeight.w700,
                              Colors.white,
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
      },
    );

    customController.dispose();
  }

  // ============================================================
  // LOCATION CONSENT
  // ============================================================

  Widget _locationConsentRow() {
    if (!isEditing) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: LocalizedText('Location Consent', style: AppText.caption),
            ),

            LocalizedText(
              locationConsent ? 'Yes' : 'No',
              style: AppText.bodyStrong,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText('Location Consent', style: AppText.label),

                const SizedBox(height: 3),

                LocalizedText(
                  'Allow TriageMY to use your location for nearby care.',
                  style: AppText.caption,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          Switch(
            value: locationConsent,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.darkTeal,
            onChanged: (value) {
              setState(() {
                locationConsent = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DECORATION
  // ============================================================

  InputDecoration _fieldDecoration({String? suffix}) {
    return InputDecoration(
      suffixText: suffix == null ? null : tr(suffix),
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
  // SECTION
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

            LocalizedText(title, style: AppText.heading),
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
