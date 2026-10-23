import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/money.dart';

/// One label to print; [copies] usually equals the pieces in stock.
class LabelSpec {
  const LabelSpec({required this.name, required this.variant, required this.priceCents, required this.barcode, required this.copies});

  final String name, variant, barcode;
  final int priceCents, copies;
}

const labelsPerPage = 24; // 3 × 8 on a letter sheet, cut along the faint lines

/// Retail symbology by length; anything that fails its check digit still prints as Code 128.
pw.Barcode symbologyFor(String code) {
  final b = switch (code.length) {
    13 => pw.Barcode.ean13(),
    8 => pw.Barcode.ean8(),
    12 => pw.Barcode.upcA(),
    _ => pw.Barcode.code128(),
  };
  return b.isValid(code) ? b : pw.Barcode.code128();
}

Future<Uint8List> buildLabelsPdf(List<LabelSpec> specs) {
  final labels = [for (final s in specs) for (var i = 0; i < s.copies; i++) s];
  final doc = pw.Document(title: 'Etiquetas Offstock');

  for (var start = 0; start < labels.length; start += labelsPerPage) {
    final page = labels.skip(start).take(labelsPerPage).toList();
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.letter.copyWith(
        marginLeft: 6 * PdfPageFormat.mm,
        marginRight: 6 * PdfPageFormat.mm,
        marginTop: 10 * PdfPageFormat.mm,
        marginBottom: 10 * PdfPageFormat.mm,
      ),
      build: (_) => pw.GridView(
        crossAxisCount: 3,
        childAspectRatio: 32.4 / 68, // label height / width in mm
        children: [for (final s in page) _label(s)],
      ),
    ));
  }
  return doc.save();
}

pw.Widget _label(LabelSpec s) => pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 4),
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(s.name, maxLines: 1, overflow: pw.TextOverflow.clip, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Row(
            children: [
              pw.Expanded(child: pw.Text(s.variant, maxLines: 1, style: const pw.TextStyle(fontSize: 8))),
              pw.Text(formatMxn(s.priceCents), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 3),
          pw.Expanded(
            child: pw.BarcodeWidget(barcode: symbologyFor(s.barcode), data: s.barcode, textStyle: const pw.TextStyle(fontSize: 7)),
          ),
        ],
      ),
    );
