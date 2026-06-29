import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../app/reports_provider.dart';
import '../../../core/reports/reports_export.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/pdf_download.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../core/widgets/delivero_skeleton.dart';
import '../../../data/models/order.dart';
import '../../../data/models/driver.dart';

String _formatInsightRupee(double amount) {
  final whole = amount == amount.roundToDouble();
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: whole ? 0 : 2,
  ).format(amount);
}

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  static const _kPresetToday = 'today';
  static const _kPresetLast7 = 'last7';
  static const _kPresetThisMonth = 'month';
  String _preset = _kPresetLast7;
  bool _exporting = false;

  Future<void> _selectDateRange() async {
    final allOrders = ref.read(ordersProvider);
    final earliest = allOrders.isEmpty
        ? DateTime(2020)
        : allOrders
              .map((o) => o.orderDate)
              .reduce((a, b) => a.isBefore(b) ? a : b);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(earliest.year, earliest.month, earliest.day),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _preset = 'custom';
        _selectedDateRange = picked;
      });
    }
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    if (preset == _kPresetToday) {
      setState(() {
        _preset = preset;
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day),
        );
      });
      return;
    }
    if (preset == _kPresetLast7) {
      setState(() {
        _preset = preset;
        _selectedDateRange = DateTimeRange(
          start: DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
          end: DateTime(now.year, now.month, now.day),
        );
      });
      return;
    }
    if (preset == _kPresetThisMonth) {
      setState(() {
        _preset = preset;
        _selectedDateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day),
        );
      });
    }
  }

  void _toast(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _exportCsv(ReportsData reports) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final csv = buildReportsCsv(
        reports: reports,
        dateRange: _selectedDateRange,
      );
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
      await Share.shareXFiles(
        [
          XFile.fromData(
            reportsCsvBytes(csv),
            name: 'delivero-insights-$stamp.csv',
            mimeType: 'text/csv',
          ),
        ],
        subject: 'Delivro insights export',
      );
    } catch (e) {
      if (mounted) _toast('Could not export CSV. Try again.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf(ReportsData reports) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
      final bytes = await buildReportsPdfBytes(
        reports: reports,
        dateRange: _selectedDateRange,
        generatedAt: DateTime.now(),
      );
      await downloadPdfFile(bytes, 'delivero-insights-$stamp.pdf');
    } catch (e) {
      if (mounted) _toast('Could not export PDF. Try again.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showProductDrilldown(ReportsData reports) {
    final products = reports.productSales.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    _showDrilldownSheet(
      title: 'Products in range',
      emptyMessage: 'No product sales in this date range.',
      rows: products
          .map(
            (p) => _DrilldownRow(
              title: p.name,
              subtitle: '${p.quantity} ${p.unit.productionWord} sold',
              value: _formatInsightRupee(p.revenue),
            ),
          )
          .toList(),
    );
  }

  void _showCustomerDrilldown(ReportsData reports) {
    final customers = reports.customerRevenue.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    _showDrilldownSheet(
      title: 'Customers in range',
      emptyMessage: 'No customer revenue in this date range.',
      rows: customers
          .map(
            (c) => _DrilldownRow(
              title: c.name,
              subtitle: '${c.orderCount} orders',
              value: _formatInsightRupee(c.revenue),
            ),
          )
          .toList(),
    );
  }

  void _showDrilldownSheet({
    required String title,
    required String emptyMessage,
    required List<_DrilldownRow> rows,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(title, style: context.appTextStyles.sectionHeader),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      emptyMessage,
                      style: context.appTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: rows.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, color: AppColors.divider),
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            row.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            row.subtitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          trailing: Text(
                            row.value,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final allOrders = ref.watch(ordersProvider);
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final drivers = ref.watch(driversProvider);
    final driversLoaded = ref.watch(driversLoadedProvider);
    final isLoading = !ordersLoaded && allOrders.isEmpty;
    final bool noOrdersYet = ordersLoaded && allOrders.isEmpty;
    final start = DateTime(
      _selectedDateRange.start.year,
      _selectedDateRange.start.month,
      _selectedDateRange.start.day,
    );
    final endExclusive = DateTime(
      _selectedDateRange.end.year,
      _selectedDateRange.end.month,
      _selectedDateRange.end.day,
    ).add(const Duration(days: 1));
    final inRange = allOrders
        .where(
          (o) =>
              !o.orderDate.isBefore(start) &&
              o.orderDate.isBefore(endExclusive),
        )
        .toList();
    final reports = (isLoading || inRange.isEmpty)
        ? ReportsData.empty()
        : computeReports(inRange);
    final df = DateFormat('MMM d');
    final rangeLabel =
        '${df.format(_selectedDateRange.start)} — ${df.format(_selectedDateRange.end)}';
    final fulfillmentRate = reports.totalOrders == 0
        ? 0.0
        : reports.completedOrders / reports.totalOrders;
    final successRateLabel =
        '${(fulfillmentRate * 100).clamp(0, 100).toStringAsFixed(1)}%';
    final topStaff = _computeTopStaff(inRange, drivers);

    if (noOrdersYet) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: DeliveroEmptyState(
          title: 'No insights yet',
          subtitle:
              'Create an order to see sales, products, and customer rankings here.',
          icon: Icons.analytics_rounded,
          actionLabel: 'Create order',
          onActionPressed: () => context.push('/owner/orders/create'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primary,
          displacement: 48,
          onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Insights',
                      style: context.appTextStyles.sliverTitle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Revenue, fulfillment, and team performance for any date range.',
                      style: context.appTextStyles.sliverSubtitle,
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reporting period',
                            style: context.appTextStyles.sectionHeader,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _PresetPill(
                                  label: 'Today',
                                  selected: _preset == _kPresetToday,
                                  onTap: () => _applyPreset(_kPresetToday),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PresetPill(
                                  label: '7 days',
                                  selected: _preset == _kPresetLast7,
                                  onTap: () => _applyPreset(_kPresetLast7),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _PresetPill(
                                  label: 'Month',
                                  selected: _preset == _kPresetThisMonth,
                                  onTap: () => _applyPreset(_kPresetThisMonth),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _selectDateRange,
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.date_range_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      rangeLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _ExportChip(
                                    label: 'CSV',
                                    icon: Icons.table_chart_rounded,
                                    onTap: _exporting
                                        ? () {}
                                        : () => _exportCsv(reports),
                                  ),
                                  const SizedBox(width: 8),
                                  _ExportChip(
                                    label: 'PDF',
                                    icon: Icons.picture_as_pdf_rounded,
                                    onTap: _exporting
                                        ? () {}
                                        : () => _exportPdf(reports),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _InsightKpiTile(
                            icon: Icons.payments_rounded,
                            iconColor: AppColors.primary,
                            iconBg: AppColors.primary.withValues(alpha: 0.12),
                            label: 'Paid sales',
                            value: _formatInsightRupee(reports.totalRevenue),
                            isLoading: isLoading,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InsightKpiTile(
                            icon: Icons.schedule_rounded,
                            iconColor: AppColors.warning,
                            iconBg: AppColors.warningLighter.withValues(
                              alpha: 0.65,
                            ),
                            label: 'Outstanding',
                            value: _formatInsightRupee(
                              reports.totalPendingRevenue,
                            ),
                            isLoading: isLoading,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _InsightKpiTile(
                      icon: Icons.verified_rounded,
                      iconColor: AppColors.success,
                      iconBg: AppColors.successLighter.withValues(alpha: 0.75),
                      label: 'Delivered ÷ total (in range)',
                      value: successRateLabel,
                      isLoading: isLoading,
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${reports.completedOrders}/${reports.totalOrders} orders',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _OrderSummaryCard(
                      reports: reports,
                      isLoading: isLoading,
                    ),
                    const SizedBox(height: 20),
                    _ReportCard(
                      title: 'Sales trend',
                      trailing: TextButton(
                        onPressed: () => _toast('Detailed view coming soon'),
                        child: Text(
                          'Details',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                        child: _SalesBarChart(dailySales: reports.dailySales),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ReportCard(
                      title: 'Delivery team',
                      trailing: IconButton(
                        tooltip: 'Filter',
                        onPressed: () => _toast('Filter coming soon'),
                        icon: const Icon(Icons.tune_rounded, size: 20),
                        color: AppColors.textSecondary,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                        child: driversLoaded && topStaff.isEmpty
                            ? Text(
                                'Assign drivers to routes to see delivery stats here.',
                                style: context.appTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : Column(
                                children: [
                                  for (final s in topStaff.take(3)) ...[
                                    _StaffRow(stat: s),
                                    if (s != topStaff.take(3).last)
                                      const Divider(
                                        height: 18,
                                        color: AppColors.divider,
                                      ),
                                  ],
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () => _toast('Coming soon'),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child: const Text(
                                        'View all staff',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ReportCard(
                      title: 'Top products',
                      trailing: TextButton(
                        onPressed: () => _showProductDrilldown(reports),
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      child: _TopProductsPreview(
                        reports: reports,
                        onOpen: () => _showProductDrilldown(reports),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ReportCard(
                      title: 'Top customers',
                      trailing: TextButton(
                        onPressed: () => _showCustomerDrilldown(reports),
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      child: _TopCustomersPreview(
                        reports: reports,
                        onOpen: () => _showCustomerDrilldown(reports),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InsightsFooterTip(
                      onLearnMore: () => _toast(
                        'Use CSV for spreadsheets or PDF for sharing with your team.',
                        color: AppColors.info,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PresetPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? onPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ExportChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightKpiTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final Widget? trailing;
  final bool isLoading;

  const _InsightKpiTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    this.trailing,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const Spacer(),
              if (trailing != null && !isLoading) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: context.appTextStyles.caption.copyWith(
              color: AppColors.textLight,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          if (isLoading)
            const DeliveroSkeleton(height: 24, width: 120)
          else
            Text(
              value,
              style: context.appTextStyles.sectionHeader.copyWith(
                fontSize: 19,
                letterSpacing: -0.5,
              ),
            ),
        ],
      ),
    );
  }
}

class _InsightsFooterTip extends StatelessWidget {
  final VoidCallback onLearnMore;

  const _InsightsFooterTip({required this.onLearnMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary.withValues(alpha: 0.85),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports',
                  style: context.appTextStyles.sectionHeader.copyWith(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Export insights as CSV or PDF for the selected date range.',
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                TextButton(
                  onPressed: onLearnMore,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.primary,
                  ),
                  child: const Text(
                    'Learn more',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesBarChart extends StatelessWidget {
  final List<DailySalesData> dailySales;
  const _SalesBarChart({required this.dailySales});

  @override
  Widget build(BuildContext context) {
    if (dailySales.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No sales data for this period',
            style: TextStyle(color: AppColors.textLight, fontSize: 13),
          ),
        ),
      );
    }

    final maxAmount = dailySales
        .map((d) => d.amount)
        .reduce((a, b) => a > b ? a : b);
    final yInterval = (maxAmount / 5).clamp(100.0, double.infinity);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxAmount * 1.2,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.primary,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final date = dailySales[groupIndex].date;
                final amount = rod.toY;
                return BarTooltipItem(
                  '${DateFormat('MMM d').format(date)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '₹${NumberFormat.compact().format(amount)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= dailySales.length) {
                    return const SizedBox();
                  }
                  if (dailySales.length > 7 && index % 2 != 0) {
                    return const SizedBox();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      DateFormat('dd/MM').format(dailySales[index].date),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  return Text(
                    NumberFormat.compact().format(value),
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppColors.divider.withValues(alpha: 0.5),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: dailySales.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.amount,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary,
                      AppColors.primary.withValues(alpha: 0.6),
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  width: 14,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxAmount * 1.2,
                    color: AppColors.backgroundSecondary.withValues(alpha: 0.3),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StaffStat {
  final String name;
  final int total;
  final int delivered;
  const _StaffStat({
    required this.name,
    required this.total,
    required this.delivered,
  });

  double get successRate => total == 0 ? 0 : delivered / total;
}

List<_StaffStat> _computeTopStaff(List<Order> orders, List<Driver> drivers) {
  final driverNameById = {for (final d in drivers) d.id: d.name};
  final byId = <String, _StaffStat>{};

  for (final o in orders) {
    final id = o.assignedDriver;
    if (id == null || id.trim().isEmpty) continue;
    final key = id.trim();
    final current = byId[key];
    final delivered = o.status == OrderStatus.delivered ? 1 : 0;
    if (current == null) {
      byId[key] = _StaffStat(
        name: driverNameById[key] ?? 'Driver',
        total: 1,
        delivered: delivered,
      );
    } else {
      byId[key] = _StaffStat(
        name: current.name,
        total: current.total + 1,
        delivered: current.delivered + delivered,
      );
    }
  }

  final list = byId.values.toList()
    ..sort((a, b) => b.successRate.compareTo(a.successRate));
  return list;
}

class _StaffRow extends StatelessWidget {
  final _StaffStat stat;
  const _StaffRow({required this.stat});

  @override
  Widget build(BuildContext context) {
    final pct = '${(stat.successRate * 100).clamp(0, 100).toStringAsFixed(1)}%';
    final subtitle = '${stat.delivered}/${stat.total} delivered';
    final initials = stat.name.trim().isEmpty
        ? '?'
        : stat.name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join();

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Center(
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              pct,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.successLighter.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Success',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final ReportsData reports;
  final bool isLoading;

  const _OrderSummaryCard({
    required this.reports,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      title: 'Order summary',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _OrderSummaryTile(
                  label: 'Total',
                  value: isLoading ? '—' : reports.totalOrders.toString(),
                  color: AppColors.primary,
                  background: AppColors.primary.withValues(alpha: 0.10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OrderSummaryTile(
                  label: 'Delivered',
                  value: isLoading ? '—' : reports.completedOrders.toString(),
                  color: AppColors.success,
                  background: AppColors.success.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OrderSummaryTile(
                  label: 'Pending',
                  value: isLoading ? '—' : reports.pendingOrders.toString(),
                  color: AppColors.warning,
                  background: AppColors.warning.withValues(alpha: 0.10),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OrderSummaryTile(
                  label: 'Cancelled',
                  value: isLoading ? '—' : reports.cancelledOrders.toString(),
                  color: AppColors.error,
                  background: AppColors.error.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color background;

  const _OrderSummaryTile({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.appTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: context.appTextStyles.sectionHeader.copyWith(
              color: color,
              fontSize: 20,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _ReportCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.appTextStyles.sectionHeader,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DrilldownRow {
  final String title;
  final String subtitle;
  final String value;

  const _DrilldownRow({
    required this.title,
    required this.subtitle,
    required this.value,
  });
}

class _TopProductsPreview extends StatelessWidget {
  final ReportsData reports;
  final VoidCallback onOpen;

  const _TopProductsPreview({required this.reports, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final products = reports.productSales.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    if (products.isEmpty) {
      return Text(
        'No product sales in this range.',
        style: context.appTextStyles.body.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      children: [
        for (final product in products.take(5)) ...[
          ListTile(
            onTap: onOpen,
            contentPadding: EdgeInsets.zero,
            title: Text(
              product.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${product.quantity} ${product.unit.productionWord}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Text(
              _formatInsightRupee(product.revenue),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (product != products.take(5).last)
            const Divider(height: 1, color: AppColors.divider),
        ],
      ],
    );
  }
}

class _TopCustomersPreview extends StatelessWidget {
  final ReportsData reports;
  final VoidCallback onOpen;

  const _TopCustomersPreview({required this.reports, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final customers = reports.customerRevenue.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    if (customers.isEmpty) {
      return Text(
        'No customer revenue in this range.',
        style: context.appTextStyles.body.copyWith(
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
    }

    return Column(
      children: [
        for (final customer in customers.take(5)) ...[
          ListTile(
            onTap: onOpen,
            contentPadding: EdgeInsets.zero,
            title: Text(
              customer.name,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              '${customer.orderCount} orders',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: Text(
              _formatInsightRupee(customer.revenue),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          if (customer != customers.take(5).last)
            const Divider(height: 1, color: AppColors.divider),
        ],
      ],
    );
  }
}
