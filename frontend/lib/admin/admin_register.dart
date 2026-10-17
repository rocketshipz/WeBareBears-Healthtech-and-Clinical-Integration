import 'package:flutter/material.dart';

import '../theme.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';
import 'admin_i18n.dart';

/// Registers a patient who has arrived and starts their queue / progress tracking.
class RegisterPatientPage extends StatefulWidget {
  final ValueChanged<Visit> onRegistered;

  const RegisterPatientPage({super.key, required this.onRegistered});

  @override
  State<RegisterPatientPage> createState() => _RegisterPatientPageState();
}

class _RegisterPatientPageState extends State<RegisterPatientPage> {
  final nameController = TextEditingController();
  final icController = TextEditingController();
  final ageController = TextEditingController();
  final complaintController = TextEditingController();
  final phoneController = TextEditingController();

  String sex = 'Female';
  Acuity acuity = Acuity.green;
  final Set<String> tests = {};

  @override
  void dispose() {
    nameController.dispose();
    icController.dispose();
    ageController.dispose();
    complaintController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  bool saving = false;

  Future<void> _submit() async {
    final name = nameController.text.trim();
    final complaint = complaintController.text.trim();
    final age = int.tryParse(ageController.text.trim());

    if (name.isEmpty || complaint.isEmpty || age == null) {
      showAppSnack(
        context,
        tr('Please enter the patient\'s name, age and main complaint.'),
      );
      return;
    }

    final phone = phoneController.text.trim();
    final phoneDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');

    if (phoneDigits.length < 9 || phoneDigits.length > 13) {
      showAppSnack(
        context,
        tr('Please enter the patient\'s phone number, e.g. 0123456789.'),
      );
      return;
    }

    // keep the catalog order so steps are consistent
    final orderedTests = VisitStep.testCatalog.keys
        .where((t) => tests.contains(t))
        .toList();

    setState(() => saving = true);

    final Visit visit;

    try {
      visit = await adminStore.registerPatient(
        name: name,
        ic: icController.text.trim(),
        age: age,
        sex: sex,
        complaint: complaint,
        acuity: acuity,
        tests: orderedTests,
        patientPhone: phone,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => saving = false);
      showAppSnack(context, tr('Could not register the patient. Please try again.'));
      return;
    }

    if (!mounted) return;

    nameController.clear();
    icController.clear();
    ageController.clear();
    complaintController.clear();
    phoneController.clear();

    setState(() {
      saving = false;
      sex = 'Female';
      acuity = Acuity.green;
      tests.clear();
    });

    showAppSnack(context, tr('{queue} registered.', {'queue': visit.queueNo}));
    widget.onRegistered(visit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FadeSlideIn(
                      index: 0,
                      child: Row(
                        children: [
                          BrandWordmark(size: 28),
                          SizedBox(width: 10),
                          StaffTag(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 26),

                    FadeSlideIn(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Register patient'), style: AppText.display),
                          const SizedBox(height: 6),
                          Text(
                            tr('For walk-ins. Patients who used the TriageMY app appear '
                                'under Incoming in the queue, with their details already filled in.'),
                            style: AppText.body,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // PATIENT DETAILS
                    FadeSlideIn(
                      index: 2,
                      child: _card(
                        title: tr('Patient details'),
                        children: [
                          fieldLabel(tr('Full name')),
                          const SizedBox(height: 8),
                          TextField(
                            controller: nameController,
                            style: AppText.input,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: appInputDecoration(
                              hint: tr('Patient name'),
                              icon: Icons.person_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),
                          fieldLabel(tr('IC / ID number (optional)')),
                          const SizedBox(height: 8),
                          TextField(
                            controller: icController,
                            style: AppText.input,
                            textInputAction: TextInputAction.next,
                            decoration: appInputDecoration(
                              hint: tr('e.g. 000101-00-0000'),
                              icon: Icons.badge_outlined,
                            ),
                          ),
                          const SizedBox(height: 16),
                          fieldLabel(tr('Age')),
                          const SizedBox(height: 8),
                          TextField(
                            controller: ageController,
                            style: AppText.input,
                            keyboardType: TextInputType.number,
                            decoration: appInputDecoration(
                              hint: tr('Years'),
                              icon: Icons.cake_outlined,
                            ),
                          ),
                          const SizedBox(height: 16),
                          fieldLabel(tr('Sex')),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final s in const ['Female', 'Male'])
                                SelectChip(
                                  label: tr(s),
                                  selected: sex == s,
                                  onTap: () => setState(() => sex = s),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          fieldLabel(tr('Main complaint')),
                          const SizedBox(height: 8),
                          TextField(
                            controller: complaintController,
                            style: AppText.input,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: appInputDecoration(
                              hint: tr('e.g. Chest pain'),
                              icon: Icons.healing_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ZONE
                    FadeSlideIn(
                      index: 3,
                      child: _card(
                        title: tr('Triage zone'),
                        subtitle: tr('Can be changed later after nurse triage.'),
                        children: [
                          Row(
                            children: [
                              for (final a in Acuity.values) ...[
                                Expanded(child: _zoneTile(a)),
                                if (a != Acuity.values.last)
                                  const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // TESTS
                    FadeSlideIn(
                      index: 4,
                      child: _card(
                        title: tr('Tests required'),
                        subtitle: tr('Optional. More can be added during the visit.'),
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final t in VisitStep.testCatalog.keys)
                                SelectChip(
                                  label: tr(t),
                                  selected: tests.contains(t),
                                  onTap: () => setState(() {
                                    if (!tests.remove(t)) tests.add(t);
                                  }),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // PATIENT CONTACT
                    FadeSlideIn(
                      index: 5,
                      child: _card(
                        title: tr('Patient phone number'),
                        subtitle:
                            tr('Required. The live tracking link is sent to this number.'),
                        children: [
                          TextField(
                            controller: phoneController,
                            style: AppText.input,
                            keyboardType: TextInputType.phone,
                            decoration: appInputDecoration(
                              hint: tr('e.g. 0123456789'),
                              icon: Icons.phone_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    FadeSlideIn(
                      index: 6,
                      child: PrimaryButton(
                        label: saving ? tr('Registering...') : tr('Register & start queue'),
                        icon: Icons.arrow_forward_rounded,
                        onPressed: saving ? null : _submit,
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

  Widget _zoneTile(Acuity a) {
    final selected = acuity == a;
    final color = a.color;

    return Pressable(
      onTap: () => setState(() => acuity = a),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : AppColors.field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 8),
            Text(
              a.label,
              style: AppText.style(14, FontWeight.w700, AppColors.textDark),
            ),
            Text(a.description, style: AppText.caption),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppText.heading),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle, style: AppText.caption),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}