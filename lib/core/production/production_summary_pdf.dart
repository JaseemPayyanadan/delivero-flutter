import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'production_summary.dart';

Future<Uint8List> buildProductionSummaryPdfBytes({
  required ProductionSummary summary,
  required DateTime generatedAt,
}) async {
  final doc = pw.Document();
  final dateFormat = DateFormat('MMM d, yyyy • hh:mm a');

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) {
        return [
          pw.Text(
            'Production list',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Day: ${_formatDay(summary.scopeDay)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          if (summary.routeLabel != null && summary.routeLabel!.isNotEmpty)
            pw.Text(
              'Route: ${summary.routeLabel}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          pw.Text(
            'Generated: ${dateFormat.format(generatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Orders: ${summary.activeOrders} · Products: ${summary.lines.length} · '
            'Total units: ${summary.totalUnits}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 12),
          if (summary.lines.isEmpty)
            pw.Text(
              'No items in scope.',
              style: const pw.TextStyle(fontSize: 11),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.4),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(3.4),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _headerCell('Item'),
                    _headerCell('Total units'),
                    _headerCell('Pack breakdown'),
                  ],
                ),
                ...summary.lines.map((line) {
                  final packs = formatPackBreakdown(line.packBreakdown);
                  return pw.TableRow(
                    children: [
                      _bodyCell(line.productName),
                      _bodyCell('${line.totalUnits}'),
                      _bodyCell(
                        packs.isEmpty
                            ? '${line.orderLineCount} line(s)'
                            : '$packs (${line.orderLineCount} lines)',
                      ),
                    ],
                  );
                }),
              ],
            ),
        ];
      },
    ),
  );

  return doc.save();
}

pw.Widget _headerCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(10),
    child: pw.Text(
      text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        letterSpacing: 0.6,
      ),
    ),
  );
}

pw.Widget _bodyCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(10),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 11)),
  );
}

String _formatDay(DateTime day) {
  return DateFormat('d MMM yyyy').format(day);
}
