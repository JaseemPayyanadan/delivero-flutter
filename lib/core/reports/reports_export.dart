import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../app/reports_provider.dart';

String buildReportsCsv({
  required ReportsData reports,
  required DateTimeRange dateRange,
}) {
  final df = DateFormat('yyyy-MM-dd');
  final money = NumberFormat('#,##0.##');
  final buffer = StringBuffer();

  void row(List<String> cells) {
    buffer.writeln(cells.map(_csvEscape).join(','));
  }

  row(['Delivro insights export']);
  row([
    'Period start',
    df.format(dateRange.start),
    'Period end',
    df.format(dateRange.end),
  ]);
  row([]);
  row(['Metric', 'Value']);
  row(['Paid sales', money.format(reports.totalRevenue)]);
  row(['Outstanding', money.format(reports.totalPendingRevenue)]);
  row(['Total orders', '${reports.totalOrders}']);
  row(['Delivered orders', '${reports.completedOrders}']);
  row(['Pending orders', '${reports.pendingOrders}']);
  row(['Cancelled orders', '${reports.cancelledOrders}']);
  row(['Average order value', money.format(reports.averageOrderValue)]);
  row([]);

  row(['Daily sales']);
  row(['Date', 'Orders', 'Amount']);
  for (final day in reports.dailySales) {
    row([
      df.format(day.date),
      '${day.count}',
      money.format(day.amount),
    ]);
  }
  row([]);

  row(['Top products']);
  row(['Product', 'Quantity', 'Revenue']);
  final products = reports.productSales.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  for (final product in products) {
    row([
      product.name,
      '${product.quantity}',
      money.format(product.revenue),
    ]);
  }
  row([]);

  row(['Top customers']);
  row(['Customer', 'Orders', 'Revenue']);
  final customers = reports.customerRevenue.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  for (final customer in customers) {
    row([
      customer.name,
      '${customer.orderCount}',
      money.format(customer.revenue),
    ]);
  }

  return buffer.toString();
}

Future<Uint8List> buildReportsPdfBytes({
  required ReportsData reports,
  required DateTimeRange dateRange,
  required DateTime generatedAt,
}) async {
  final doc = pw.Document();
  final df = DateFormat('MMM d, yyyy');
  final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  final products = reports.productSales.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));
  final customers = reports.customerRevenue.values.toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) {
        return [
          pw.Text(
            'Insights report',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '${df.format(dateRange.start)} — ${df.format(dateRange.end)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            'Generated: ${DateFormat('MMM d, yyyy • hh:mm a').format(generatedAt)}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Metric', 'Value'],
            data: [
              ['Paid sales', money.format(reports.totalRevenue)],
              ['Outstanding', money.format(reports.totalPendingRevenue)],
              ['Total orders', '${reports.totalOrders}'],
              ['Delivered', '${reports.completedOrders}'],
              ['Pending', '${reports.pendingOrders}'],
              ['Cancelled', '${reports.cancelledOrders}'],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.grey200),
            cellHeight: 24,
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Top products',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(height: 8),
          if (products.isEmpty)
            pw.Text('No product data in range.')
          else
            pw.Table.fromTextArray(
              headers: ['Product', 'Qty', 'Revenue'],
              data: products
                  .take(15)
                  .map(
                    (p) => [
                      p.name,
                      '${p.quantity}',
                      money.format(p.revenue),
                    ],
                  )
                  .toList(),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellHeight: 22,
            ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Top customers',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(height: 8),
          if (customers.isEmpty)
            pw.Text('No customer data in range.')
          else
            pw.Table.fromTextArray(
              headers: ['Customer', 'Orders', 'Revenue'],
              data: customers
                  .take(15)
                  .map(
                    (c) => [
                      c.name,
                      '${c.orderCount}',
                      money.format(c.revenue),
                    ],
                  )
                  .toList(),
              cellStyle: const pw.TextStyle(fontSize: 10),
              cellHeight: 22,
            ),
        ];
      },
    ),
  );

  return doc.save();
}

String _csvEscape(String value) {
  final needsQuotes =
      value.contains(',') || value.contains('"') || value.contains('\n');
  if (!needsQuotes) return value;
  return '"${value.replaceAll('"', '""')}"';
}

Uint8List reportsCsvBytes(String csv) => Uint8List.fromList(utf8.encode(csv));
