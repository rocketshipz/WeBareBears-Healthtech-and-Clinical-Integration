import '../localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/triage_chat_service.dart';
import '../theme.dart';
import 'home_page.dart';
import 'hospital_routing.dart';
import 'profile_page.dart';

// ============================================================
// REPORT DATA  (built from the answers given in the triage engine)
// ============================================================

class TriageReportData {
  final String? symptom;
  final String? severity;
  final String? duration;
  final List<String> dangerSigns;
  final DateTime createdAt;

  /// Set when the level comes from the backend rules engine (chat triage).
  final int? levelOverride;
  final String? recommendationOverride;

  TriageReportData({
    required this.symptom,
    required this.severity,
    required this.duration,
    required Iterable<String> dangerSigns,
    DateTime? createdAt,
    this.levelOverride,
    this.recommendationOverride,
  })  : dangerSigns = dangerSigns
            .where((s) => s != 'None of these')
            .map((s) => s.replaceAll('\n', ' '))
            .toList(),
        createdAt = createdAt ?? DateTime.now();

  bool get hasDangerSigns => dangerSigns.isNotEmpty;

  /// Simple prototype rules: NOT a clinical algorithm.
  int get level {
    if (levelOverride != null) return levelOverride!;
    if (hasDangerSigns) return 1;
    if (severity == 'Severe') return 2;
    if (severity == 'Moderate') return 3;
    if (severity == 'Mild' && duration == 'More than 3 days') return 3;
    return 4;
  }

  String get zone {
    if (level == 1) return 'Red Zone';
    if (level <= 3) return 'Yellow Zone';
    return 'Green Zone';
  }

  String get zoneLabel => '$zone · Level $level';

  Color get color {
    if (level == 1) return AppColors.red;
    if (level <= 3) return const Color(0xFFE59A12);
    return AppColors.green;
  }

  String get headline {
    if (level == 1) return 'Emergency care advised';
    if (level == 2) return 'Urgent assessment advised';
    if (level == 3) return 'Medical review advised';
    return 'Non-critical case';
  }

  String get recommendation {
    if (recommendationOverride != null) return recommendationOverride!;
    if (level == 1) {
      return 'You reported danger signs. Call 999 or go to the nearest '
          'emergency department immediately.';
    }
    if (level == 2) {
      return 'Your symptoms are severe. Seek medical care as soon as possible '
          'and do not wait for them to worsen.';
    }
    if (level == 3) {
      return 'Arrange to see a doctor within the next day. Seek care sooner '
          'if your symptoms get worse.';
    }
    return 'Your screening indicates a non-critical case. You may consider '
        'facilities with a shorter waiting time.';
  }

  String get reportId {
    final d = createdAt;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'TMY-${d.year}${two(d.month)}${two(d.day)}-'
        '${two(d.hour)}${two(d.minute)}';
  }

  String get dateText {
    final d = createdAt;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, '
        '${two(d.hour)}:${two(d.minute)}';
  }

  String get _none => 'Not specified';

  List<MapEntry<String, String>> get symptomRows => [
        MapEntry('Main symptom', symptom ?? _none),
        MapEntry('Severity', severity ?? _none),
        MapEntry('Duration', duration ?? _none),
        MapEntry(
          'Danger signs',
          hasDangerSigns ? dangerSigns.join(', ') : 'None reported',
        ),
      ];

  List<MapEntry<String, String>> patientRows(Map<String, String> p) => [
        MapEntry('Name', p['name'] ?? '-'),
        MapEntry('Age / Sex', '${p['age'] ?? '-'} / ${p['sex'] ?? '-'}'),
        MapEntry('Blood type', p['blood'] ?? '-'),
        MapEntry('Allergies', p['allergies'] ?? '-'),
        MapEntry('Chronic conditions', p['chronic'] ?? '-'),
        MapEntry('Current medication', p['medication'] ?? '-'),
      ];

  String toPlainText(Map<String, String> profile) {
    final b = StringBuffer()
      ..writeln('TriageMY - Triage Report')
      ..writeln('Report ID: $reportId')
      ..writeln('Date: $dateText')
      ..writeln()
      ..writeln('Outcome: $zoneLabel ($headline)')
      ..writeln(recommendation)
      ..writeln()
      ..writeln('SYMPTOMS');
    for (final r in symptomRows) {
      b.writeln('${r.key}: ${r.value}');
    }
    b
      ..writeln()
      ..writeln('PATIENT');
    for (final r in patientRows(profile)) {
      b.writeln('${r.key}: ${r.value}');
    }
    b
      ..writeln()
      ..writeln(
        'This is a screening aid, not a medical diagnosis. '
        'In an emergency call 999.',
      );
    return b.toString().split('\n').map(tr).join('\n');
  }

  // ----------------------------------------------------------
  // PDF
  // ----------------------------------------------------------

  Future<Uint8List> buildPdf(Map<String, String> profile) async {
    String clean(String s) => tr(s)
        .replaceAll('–', '-')
        .replaceAll('·', '-')
        .replaceAll('\n', ' ');

    final accent = level == 1
        ? PdfColor.fromHex('#ED254E')
        : level <= 3
            ? PdfColor.fromHex('#E59A12')
            : PdfColor.fromHex('#2E9E6B');
    final dark = PdfColor.fromHex('#0D5C63');
    final grey = PdfColor.fromHex('#6B7B7D');

    pw.Widget section(String title, List<MapEntry<String, String>> rows) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(height: 18),
          pw.Text(
            tr(title),
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: dark,
            ),
          ),
          pw.Divider(color: PdfColor.fromHex('#E3EAEA')),
          for (final r in rows)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 150,
                    child: pw.Text(
                      tr(clean(r.key)),
                      style: pw.TextStyle(fontSize: 11, color: grey),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      tr(clean(r.value)),
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                tr('TriageMY'),
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: dark,
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    tr('Triage Report'),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    tr(clean('$reportId  |  $dateText')),
                    style: pw.TextStyle(fontSize: 10, color: grey),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: accent, width: 1.5),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  tr(clean(zoneLabel)),
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: accent,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  tr(headline),
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(tr(recommendation), style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
          section('Reported symptoms', symptomRows),
          section('Patient information', patientRows(profile)),
          pw.SizedBox(height: 26),
          pw.Text(
            tr('This report is a screening aid generated from the answers you '
            'provided. It is not a medical diagnosis. If your symptoms become '
            'severe or you develop emergency warning signs, call 999 or seek '
            'emergency care immediately.'),
            style: pw.TextStyle(fontSize: 9, color: grey),
          ),
        ],
      ),
    );

    return doc.save();
  }
}

// ============================================================
// REPORT PAGE
// ============================================================

class TriageReportPage extends StatelessWidget {
  final TriageReportData report;

  /// Id of the report stored on the server (null when not logged in).
  final String? storedReportId;

  /// The screening was said to be for someone else.
  final bool forSomeoneElse;

  const TriageReportPage({
    super.key,
    required this.report,
    this.storedReportId,
    this.forSomeoneElse = false,
  });

  Map<String, String> get _profile => profileData.value;

  Future<void> _savePdf(BuildContext context) async {
    try {
      final bytes = await report.buildPdf(_profile);

      await Printing.sharePdf(
        bytes: bytes,
        filename: 'TriageMY_${report.reportId}.pdf',
      );
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'Could not create the PDF. Please try again.');
      }
    }
  }

  Future<void> _print(BuildContext context) async {
    try {
      await Printing.layoutPdf(
        name: 'TriageMY_${report.reportId}',
        onLayout: (_) => report.buildPdf(_profile),
      );
    } catch (_) {
      if (context.mounted) {
        showAppSnack(context, 'Could not open the print dialog.');
      }
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: report.toPlainText(_profile)),
    );

    if (context.mounted) {
      showAppSnack(context, 'Report copied to clipboard.');
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    return Scaffold(
      bottomNavigationBar: AppBottomNav(
        selectedIndex: 1,
        onSelected: (index) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => MainNavigation(initialIndex: index),
            ),
            (route) => false,
          );
        },
      ),
      body: GradientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOP BAR
                    FadeSlideIn(
                      index: 0,
                      child: Row(
                        children: [
                          CircleBackButton(
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 14),
                          const BrandWordmark(),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),

                    FadeSlideIn(
                      index: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText('Triage Report', style: AppText.display),
                          const SizedBox(height: 8),
                          LocalizedText(
                            'A summary of your screening, ready to save or share.',
                            style: AppText.body,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // THE REPORT "DOCUMENT"
                    FadeSlideIn(index: 2, child: _document()),

                    const SizedBox(height: 18),

                    // ACTION ICONS
                    FadeSlideIn(
                      index: 3,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _actionIcon(
                            icon: Icons.picture_as_pdf_outlined,
                            label: 'Save PDF',
                            onTap: () => _savePdf(context),
                          ),
                          const SizedBox(width: 22),
                          _actionIcon(
                            icon: Icons.print_outlined,
                            label: 'Print',
                            onTap: () => _print(context),
                          ),
                          const SizedBox(width: 22),
                          _actionIcon(
                            icon: Icons.copy_rounded,
                            label: 'Copy',
                            onTap: () => _copy(context),
                          ),
                        ],
                      ),
                    ),

                    if (storedReportId != null) ...[
                      const SizedBox(height: 22),
                      FadeSlideIn(
                        index: 4,
                        child: _SubjectLinkCard(
                          reportId: storedReportId!,
                          initiallyOpen: forSomeoneElse,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    FadeSlideIn(
                      index: 5,
                      child: PrimaryButton(
                        label: 'Hospital routing',
                        icon: Icons.navigation_outlined,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  RecommendedHospitalsPage(report: report),
                            ),
                          );
                        },
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

  // ------------------------------------------------------------

  Widget _document() {
    final color = report.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 18,
                color: AppColors.teal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: LocalizedText(report.reportId, style: AppText.label),
              ),
              LocalizedText(report.dateText, style: AppText.caption),
            ],
          ),

          const SizedBox(height: 16),

          // outcome
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: color.withValues(alpha: 0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText('Triage outcome', style: AppText.caption),
                const SizedBox(height: 2),
                LocalizedText(
                  report.zoneLabel,
                  style: AppText.style(18, FontWeight.w700, color),
                ),
                const SizedBox(height: 2),
                LocalizedText(report.headline, style: AppText.bodyStrong),
                const SizedBox(height: 6),
                LocalizedText(report.recommendation, style: AppText.body),
              ],
            ),
          ),

          const SizedBox(height: 20),

          _sectionTitle('Reported symptoms'),
          for (final r in report.symptomRows) _row(r.key, r.value),

          const SizedBox(height: 20),

          _sectionTitle('Patient information'),
          for (final r in report.patientRows(_profile)) _row(r.key, r.value),

          const SizedBox(height: 16),

          LocalizedText(
            'This report is a screening aid, not a medical diagnosis. '
            'In an emergency, call 999.',
            style: AppText.caption,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(text, style: AppText.heading),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.border),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 4, child: LocalizedText(label, style: AppText.caption)),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: LocalizedText(
              value,
              textAlign: TextAlign.right,
              style: AppText.bodyStrong,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionIcon({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: cardDecoration(radius: 18),
            child: Icon(icon, color: AppColors.darkTeal, size: 24),
          ),
          const SizedBox(height: 6),
          LocalizedText(label, style: AppText.caption),
        ],
      ),
    );
  }
}

// ============================================================
// SCREENING FOR SOMEONE ELSE  (link the report to their account by IC)
// ============================================================

class _SubjectLinkCard extends StatefulWidget {
  final String reportId;
  final bool initiallyOpen;

  const _SubjectLinkCard({required this.reportId, required this.initiallyOpen});

  @override
  State<_SubjectLinkCard> createState() => _SubjectLinkCardState();
}

class _SubjectLinkCardState extends State<_SubjectLinkCard> {
  final TextEditingController _icController = TextEditingController();
  late bool _open = widget.initiallyOpen;
  bool _saving = false;
  bool _linked = false;
  String? _error;

  @override
  void dispose() {
    _icController.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final ic = _icController.text.trim();
    if (ic.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await TriageChatService.linkReportSubject(widget.reportId, ic);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _linked = error == null;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return Center(
        child: TextButton(
          onPressed: () => setState(() => _open = true),
          child: LocalizedText(
            'This screening was for someone else?',
            style: AppText.style(14, FontWeight.w600, AppColors.teal),
          ),
        ),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText('Screening for someone else', style: AppText.heading),
          const SizedBox(height: 6),
          LocalizedText(
            'If the person has a TriageMY account, enter their IC number. '
            'The hospital can then find this report when they check in.',
            style: AppText.body,
          ),
          const SizedBox(height: 14),
          if (_linked)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.green, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: LocalizedText(
                    'Report linked to their account.',
                    style: AppText.bodyStrong,
                  ),
                ),
              ],
            )
          else ...[
            TextField(
              controller: _icController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              style: AppText.input,
              decoration: appInputDecoration(
                hint: 'IC number, e.g. 600202-02-2222',
                icon: Icons.badge_outlined,
              ),
              onSubmitted: (_) => _link(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              LocalizedText(
                _error!,
                style: AppText.style(13, FontWeight.w500, AppColors.red),
              ),
            ],
            const SizedBox(height: 14),
            PrimaryButton(
              label: _saving ? 'Linking...' : 'Link to their account',
              icon: Icons.link_rounded,
              onPressed: _saving ? null : _link,
            ),
          ],
        ],
      ),
    );
  }
}
