import 'package:flutter/material.dart';

import '../theme.dart';

class PatientProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final String title;
  const PatientProfileCard({
    super.key,
    required this.profile,
    this.title = 'Patient profile',
  });

  static String format(dynamic value) {
    if (value == null || value == '' || value == 'unknown') {
      return 'Not recorded';
    }
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) {
      return value.isEmpty ? 'None recorded' : value.map(format).join('\n');
    }
    if (value is Map) {
      return value.values
          .where((v) => v != null && v.toString().isNotEmpty)
          .map(format)
          .join(' · ');
    }
    final text = value.toString();
    return [
          'male',
          'female',
          'intersex',
          'never',
          'former',
          'current',
          'none',
          'occasional',
          'regular',
        ].contains(text)
        ? '${text[0].toUpperCase()}${text.substring(1)}'
        : text;
  }

  static String label(String key) => key
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  static String timestamp(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return 'Not recorded';
    final local = date.toUtc().add(const Duration(hours: 8));
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    return '${local.day} ${months[local.month - 1]}, $hour.${local.minute.toString().padLeft(2, '0')}${local.hour < 12 ? 'am' : 'pm'}';
  }

  Widget field(String label, dynamic value, {String unit = ''}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: AppText.caption),
      const SizedBox(height: 5),
      SelectableText(
        '${format(value)}${value == null || value == '' ? '' : unit}',
        style: AppText.bodyStrong,
      ),
    ],
  );

  Widget grid(List<Widget> fields) => LayoutBuilder(
    builder: (context, size) {
      final columns = size.maxWidth >= 720
          ? 3
          : size.maxWidth >= 300
          ? 2
          : 1;
      final width = (size.maxWidth - (columns - 1) * 24) / columns;
      return Wrap(
        spacing: 24,
        runSpacing: 20,
        children: [
          for (final item in fields) SizedBox(width: width, child: item),
        ],
      );
    },
  );

  Widget section(String label, List<Widget> fields) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 18),
        Text(label, style: AppText.heading),
        const SizedBox(height: 18),
        grid(fields),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: cardDecoration(radius: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.heading),
        const SizedBox(height: 20),
        if (title != 'Patient profile')
          grid([
            field('Main symptom', profile['symptom']),
            field('Severity', profile['severity']),
            field('Duration', profile['duration']),
            field('Triage level', profile['level']),
            field('Danger signs', profile['danger_signs']),
            field('Submitted', timestamp(profile['submitted_at'])),
          ])
        else ...[
          Text(format(profile['name']), style: AppText.display),
          const SizedBox(height: 20),
          grid([
            field('IC number', profile['ic']),
            field('Phone number', profile['phone']),
            field('Age', profile['age'], unit: ' years'),
            field('Sex', profile['sex_at_birth']),
            field('Nationality', profile['nationality']),
            field('Preferred language', profile['preferred_language']),
            field('Height', profile['height_cm'], unit: ' cm'),
            field('Weight', profile['weight_kg'], unit: ' kg'),
            field('Blood type', profile['blood_type']),
          ]),
          section('Medical background', [
            field('Chronic conditions', profile['chronic_conditions']),
            field('Allergies', profile['allergies']),
            field('Current medications', profile['current_medications']),
            field('Past surgeries', profile['past_surgeries']),
            field('Family history', profile['family_history']),
            field('Organ donor', profile['organ_donor']),
            field('Smoking', profile['smoking_status']),
            field('Alcohol use', profile['alcohol_use']),
          ]),
          section('Emergency contact', [
            field('Name', profile['emergency_contact_name']),
            field('Phone number', profile['emergency_contact_phone']),
            field('Relationship', profile['emergency_contact_relation']),
          ]),
          if (profile['medical_info_updated_at'] != null) ...[
            const SizedBox(height: 24),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              'Medical info updated · ${timestamp(profile['medical_info_updated_at'])}',
              style: AppText.caption,
            ),
          ],
        ],
      ],
    ),
  );
}
