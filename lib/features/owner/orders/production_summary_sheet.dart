import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../../core/production/production_summary.dart';
import '../../../core/production/production_summary_pdf.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/delivery_route.dart';
import '../../../data/models/order.dart';

/// Bottom sheet: kitchen / production list for scoped orders.
class ProductionSummarySheet extends StatelessWidget {
  final ProductionSummary summary;
  final VoidCallback? onChangeDate;

  const ProductionSummarySheet({
    super.key,
    required this.summary,
    this.onChangeDate,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductionSummary summary,
    VoidCallback? onChangeDate,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductionSummarySheet(
        summary: summary,
        onChangeDate: onChangeDate,
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    final text = formatProductionSummaryText(summary);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Production list copied for kitchen.',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context) async {
    if (summary.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No items to download for this scope.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final filename =
        'production_list_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf';
    final bytes = await buildProductionSummaryPdfBytes(
      summary: summary,
      generatedAt: now,
    );

    await Printing.sharePdf(
      bytes: bytes,
      filename: filename,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Save the PDF from the share menu (e.g. Files or Downloads).',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayLabel = DateFormat('EEE, d MMM yyyy').format(summary.scopeDay);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Production list',
                            style: context.appTextStyles.sectionHeader,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayLabel,
                            style: context.appTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (summary.routeLabel != null &&
                              summary.routeLabel!.trim().isNotEmpty)
                            Text(
                              summary.routeLabel!.trim(),
                              style: context.appTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onChangeDate != null)
                      IconButton(
                        tooltip: 'Change date',
                        onPressed: onChangeDate,
                        icon: const Icon(Icons.calendar_today_rounded),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SummaryStatsRow(summary: summary),
              ),
              if (summary.ordersByType.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _OrderTypeChips(summary: summary),
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              Flexible(
                child: summary.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No items for this day and filters.\n'
                          'Try another date or route.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        itemCount: summary.lines.length,
                        separatorBuilder: (_, _) => const Divider(height: 28),
                        itemBuilder: (context, index) {
                          final line = summary.lines[index];
                          return _ProductionLineTile(line: line);
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _copyToClipboard(context),
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text(
                          'Copy',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _downloadPdf(context),
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text(
                          'Download',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
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
    );
  }
}

class _SummaryStatsRow extends StatelessWidget {
  final ProductionSummary summary;

  const _SummaryStatsRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            label: 'Orders',
            value: '${summary.activeOrders}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Products',
            value: '${summary.lines.length}',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatChip(
            label: 'Total units',
            value: '${summary.totalUnits}',
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.appTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTypeChips extends StatelessWidget {
  final ProductionSummary summary;

  const _OrderTypeChips({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: OrderType.values.map((type) {
        final count = summary.ordersByType[type];
        if (count == null || count == 0) return const SizedBox.shrink();
        final label = switch (type) {
          OrderType.daily => 'Daily',
          OrderType.oneTime => 'One-time',
          OrderType.special => 'Special',
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primaryLighter,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$label: $count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ProductionLineTile extends StatelessWidget {
  final ProductionLineSummary line;

  const _ProductionLineTile({required this.line});

  @override
  Widget build(BuildContext context) {
    final packEntries = line.packBreakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                line.productName.toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            Text(
              '${line.totalUnits} units',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${line.orderLineCount} order line${line.orderLineCount == 1 ? '' : 's'}',
          style: context.appTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (packEntries.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: packEntries.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${e.value}×${e.key} packs',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

/// Opens production sheet with scope derived from orders + routes.
Future<void> showProductionSummaryForOrders(
  BuildContext context, {
  required List<Order> allOrders,
  required List<DeliveryRoute> routes,
  required DateTime day,
  String? routeId,
  String? routeLabel,
  VoidCallback? onChangeDate,
}) {
  final scope = ProductionSummaryScope(
    day: day,
    routeId: routeId,
    routes: routes,
    routeLabel: routeLabel,
  );
  final summary = buildProductionSummary(allOrders, scope);
  return ProductionSummarySheet.show(
    context,
    summary: summary,
    onChangeDate: onChangeDate,
  );
}
