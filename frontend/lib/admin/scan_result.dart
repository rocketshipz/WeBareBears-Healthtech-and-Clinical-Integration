import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';

import '../theme.dart';
import 'admin_pdf.dart';
import 'admin_store.dart';
import 'admin_widgets.dart';
import 'admin_i18n.dart';

// ============================================================
// SCAN A RESULT DOCUMENT  ->  PDF  ->  upload
// ============================================================

/// Staff photograph / scan the paper result (one or more pages). The pages are
/// combined into a single PDF and uploaded, so the patient and the doctors can
/// open it from their side.
class ScanResultPage extends StatefulWidget {
  final Visit visit;
  final VisitStep step;

  const ScanResultPage({super.key, required this.visit, required this.step});

  @override
  State<ScanResultPage> createState() => _ScanResultPageState();
}

class _ScanResultPageState extends State<ScanResultPage> {
  final ImagePicker _picker = ImagePicker();
  final List<Uint8List> pages = [];

  bool busy = false;
  bool confirmed = false;
  String? error;

  /// The smart document scanner (edge detection, crop, flatten) only exists on
  /// phones. On web / desktop we fall back to a normal photo or file picker.
  bool get _hasDocumentScanner =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Opens the phone's document scanner. It detects the page edges, crops and
  /// straightens the paper, and can scan several pages in one go.
  Future<void> _scanDocument() async {
    if (!_hasDocumentScanner) {
      return _capture(ImageSource.camera);
    }

    try {
      final paths = await CunningDocumentScanner.getPictures(
        noOfPages: 10,
        scannerSource: ScannerSource.cameraAndGallery,
      );

      // user closed the scanner without scanning anything
      if (paths == null || paths.isEmpty) return;

      final scanned = <Uint8List>[];

      for (final path in paths) {
        scanned.add(await XFile(path).readAsBytes());
      }

      if (!mounted) return;
      setState(() {
        pages.addAll(scanned);
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        tr('Could not open the scanner. Using the camera instead.'),
      );
      await _capture(ImageSource.camera);
    }
  }

  Future<void> _capture(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 80,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();

      if (!mounted) return;
      setState(() {
        pages.add(bytes);
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      showAppSnack(
        context,
        tr('Could not open the camera. Try "Choose from gallery" instead.'),
      );
    }
  }

  Future<void> _upload() async {
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final pdf = await buildPdfFromImages(pages);

      await adminStore.addResult(widget.visit, widget.step, pdf, pages.length);

      if (!mounted) return;
      showAppSnack(
        context,
        tr('{name} result uploaded.', {'name': widget.step.displayName}),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = tr('Upload failed. Check the connection and try again. '
            'Your scanned pages are still here.');
      });
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.visit;

    return Scaffold(
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
                    Row(
                      children: [
                        CircleBackButton(onTap: () => Navigator.pop(context)),
                        const SizedBox(width: 14),
                        Text(tr('Scan results'), style: AppText.heading),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // WHO THIS IS FOR
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: cardDecoration(radius: 22),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppColors.paleTeal,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              widget.step.icon,
                              color: AppColors.darkTeal,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.step.displayName, style: AppText.heading),
                                const SizedBox(height: 2),
                                Text(
                                  '${v.queueNo} · ${v.name}',
                                  style: AppText.bodyStrong,
                                ),
                                Text(
                                  '${tr('{n} yrs', {'n': v.age})} · ${trText(v.sex)}'
                                  '${v.ic.isEmpty ? '' : ' · ${v.ic}'}',
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                          ),
                          AcuityPill(acuity: v.acuity),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    Text(
                      _hasDocumentScanner
                          ? tr('Place the document flat in good light. The scanner '
                              'finds the page edges and straightens it. You can '
                              'scan several pages in one go.')
                          : tr('Place the document flat in good light. Add one photo per page.'),
                      style: AppText.body,
                    ),

                    const SizedBox(height: 16),

                    // PAGES
                    if (pages.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 34),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.document_scanner_outlined,
                              size: 36,
                              color: AppColors.teal,
                            ),
                            const SizedBox(height: 8),
                            Text(tr('No pages yet'), style: AppText.bodyStrong),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var i = 0; i < pages.length; i++)
                            _thumb(i),
                        ],
                      ),

                    const SizedBox(height: 18),

                    PrimaryButton(
                      label: pages.isEmpty ? tr('Scan first page') : tr('Scan another page'),
                      icon: Icons.photo_camera_outlined,
                      onPressed: busy ? null : _scanDocument,
                    ),

                    const SizedBox(height: 10),

                    SecondaryButton(
                      label: tr('Choose from gallery'),
                      onPressed: () {
                        if (!busy) _capture(ImageSource.gallery);
                      },
                    ),

                    if (pages.isNotEmpty) ...[
                      const SizedBox(height: 24),

                      // wrong-patient safety check
                      Pressable(
                        onTap: () => setState(() => confirmed = !confirmed),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: confirmed
                                  ? AppColors.darkTeal
                                  : AppColors.border,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                confirmed
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                color: confirmed
                                    ? AppColors.darkTeal
                                    : AppColors.grey,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tr('The name on the document matches {name}.', {'name': v.name}),
                                  style: AppText.bodyStrong,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          error!,
                          style: AppText.style(12, FontWeight.w600, AppColors.red),
                        ),
                      ],

                      const SizedBox(height: 16),

                      PrimaryButton(
                        label: busy
                            ? tr('Uploading...')
                            : tr('Upload as PDF ({pages})', {
                                'pages': tr(
                                  pages.length == 1 ? '{n} page' : '{n} pages',
                                  {'n': pages.length},
                                ),
                              }),
                        icon: Icons.cloud_upload_outlined,
                        onPressed: (busy || !confirmed) ? null : _upload,
                      ),

                      const SizedBox(height: 10),

                      Center(
                        child: Text(
                          tr('Patient and doctors can open it once uploaded.'),
                          style: AppText.caption,
                        ),
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

  Widget _thumb(int i) {
    return SizedBox(
      width: 104,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 104,
                height: 136,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                  color: Colors.white,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(pages[i], fit: BoxFit.cover),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Pressable(
                  onTap: () => setState(() {
                    pages.removeAt(i);
                    if (pages.isEmpty) confirmed = false;
                  }),
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('Page {n}', {'n': i + 1}), style: AppText.caption),
        ],
      ),
    );
  }
}

// ============================================================
// VIEW A RESULT PDF
// ============================================================

class ResultViewerPage extends StatelessWidget {
  final TestResult result;

  const ResultViewerPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.darkTeal,
        title: Text(result.fileName, style: AppText.bodyStrong),
      ),
      body: FutureBuilder<Uint8List>(
        future: adminStore.loadResultBytes(result),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError || snap.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Could not load this document.'),
                  style: AppText.body,
                ),
              ),
            );
          }

          final bytes = snap.data!;

          return PdfPreview(
            build: (_) async => bytes,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            pdfFileName: result.fileName,
          );
        },
      ),
    );
  }
}