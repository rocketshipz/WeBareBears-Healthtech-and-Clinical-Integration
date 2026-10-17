import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Turns scanned page photos (JPEG / PNG) into one multi-page A4 PDF.
Future<Uint8List> buildPdfFromImages(List<Uint8List> images) async {
  final doc = pw.Document();

  for (final bytes in images) {
    final image = pw.MemoryImage(bytes);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (context) => pw.Center(
          child: pw.Image(image, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }

  return doc.save();
}