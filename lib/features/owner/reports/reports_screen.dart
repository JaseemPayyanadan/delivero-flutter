import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// How the selected range is benchmarked in the Overview deltas.
enum _Comparison { previousPeriod, previousYear }

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
  _Comparison _comparison = _Comparison.previousPeriod;
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
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(reportsCsvBytes(csv), mimeType: 'text/csv')],
          fileNameOverrides: ['delivero-insights-$stamp.csv'],
          subject: 'Delivro insights export',
        ),
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

  /// The mockup collapses CSV + PDF into one Export affordance; the sheet keeps
  /// both formats reachable.
  void _showExportSheet(ReportsData reports) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.table_chart_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Export CSV',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Open in a spreadsheet'),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportCsv(reports);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Export PDF',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text('Share with your team'),
              onTap: () {
                Navigator.of(ctx).pop();
                _exportPdf(reports);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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

  void _showStaffDrilldown(List<_StaffStat> staff) {
    _showDrilldownSheet(
      title: 'Delivery team in range',
      emptyMessage: 'Assign drivers to routes to see delivery stats here.',
      rows: staff
          .map(
            (s) => _DrilldownRow(
              title: s.name,
              subtitle: '${s.delivered}/${s.total} delivered',
              value:
                  '${(s.successRate * 100).clamp(0, 100).toStringAsFixed(1)}%',
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
                      separatorBuilder: (_, _) =>
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

  DateTimeRange _baselineRange(DateTimeRange range) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final end = DateTime(range.end.year, range.end.month, range.end.day);
    if (_comparison == _Comparison.previousYear) {
      return DateTimeRange(
        start: DateTime(start.year - 1, start.month, start.day),
        end: DateTime(end.year - 1, end.month, end.day),
      );
    }
    final days = end.difference(start).inDays + 1;
    final prevEnd = start.subtract(const Duration(days: 1));
    return DateTimeRange(
      start: prevEnd.subtract(Duration(days: days - 1)),
      end: prevEnd,
    );
  }

  String get _comparisonLabel {
    if (_comparison == _Comparison.previousYear) return 'vs last year';
    final days =
        DateTime(
              _selectedDateRange.end.year,
              _selectedDateRange.end.month,
              _selectedDateRange.end.day,
            )
            .difference(
              DateTime(
                _selectedDateRange.start.year,
                _selectedDateRange.start.month,
                _selectedDateRange.start.day,
              ),
            )
            .inDays +
        1;
    if (days <= 1) return 'vs previous day';
    return 'vs previous $days days';
  }

  List<Order> _ordersIn(List<Order> orders, DateTimeRange range) {
    final start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final endExclusive = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    ).add(const Duration(days: 1));
    return orders
        .where(
          (o) =>
              !o.orderDate.isBefore(start) &&
              o.orderDate.isBefore(endExclusive),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allOrders = ref.watch(ordersProvider);
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final drivers = ref.watch(driversProvider);
    final isLoading = !ordersLoaded && allOrders.isEmpty;
    final bool noOrdersYet = ordersLoaded && allOrders.isEmpty;

    final inRange = _ordersIn(allOrders, _selectedDateRange);
    final baseline = _ordersIn(allOrders, _baselineRange(_selectedDateRange));

    final reports = (isLoading || inRange.isEmpty)
        ? ReportsData.empty()
        : computeReports(inRange);
    final prevReports = baseline.isEmpty
        ? ReportsData.empty()
        : computeReports(baseline);

    final df = DateFormat('MMM d');
    final rangeLabel =
        '${df.format(_selectedDateRange.start)} – ${df.format(_selectedDateRange.end)}';

    double rate(ReportsData r) =>
        r.totalOrders == 0 ? 0 : r.completedOrders / r.totalOrders;
    final fulfillmentRate = rate(reports);
    final successRateLabel =
        '${(fulfillmentRate * 100).clamp(0, 100).toStringAsFixed(1)}%';
    final topStaff = _computeTopStaff(inRange, drivers);

    if (noOrdersYet) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: AppColors.backgroundSecondary,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _ReportsScreenHeader(),
                Expanded(
                  child: DeliveroEmptyState(
                    title: 'No insights yet',
                    subtitle:
                        'Create an order to see sales, products, and customer rankings here.',
                    icon: Icons.analytics_rounded,
                    actionLabel: 'Create order',
                    onActionPressed: () => context.push('/owner/orders/create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
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
                SliverToBoxAdapter(
                  child: _ReportsScreenHeader(onDateRange: _selectDateRange),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _PeriodCard(
                        preset: _preset,
                        rangeLabel: rangeLabel,
                        comparisonLabel: _comparisonLabel,
                        comparison: _comparison,
                        onPreset: _applyPreset,
                        onDateRange: _selectDateRange,
                        onComparisonChanged: (c) =>
                            setState(() => _comparison = c),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle('Overview'),
                      const SizedBox(height: 10),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _InsightKpiTile(
                                icon: Icons.payments_rounded,
                                iconColor: AppColors.primary,
                                iconBg: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                label: 'Paid Sales',
                                value: _formatInsightRupee(
                                  reports.totalRevenue,
                                ),
                                delta: _Delta.between(
                                  reports.totalRevenue,
                                  prevReports.totalRevenue,
                                ),
                                comparisonLabel: _comparisonLabel,
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
                                delta: _Delta.between(
                                  reports.totalPendingRevenue,
                                  prevReports.totalPendingRevenue,
                                  lowerIsBetter: true,
                                ),
                                comparisonLabel: _comparisonLabel,
                                isLoading: isLoading,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InsightKpiTile(
                        icon: Icons.verified_rounded,
                        iconColor: AppColors.success,
                        iconBg: AppColors.successLighter.withValues(
                          alpha: 0.75,
                        ),
                        label: 'Delivered + Total (in range)',
                        value: successRateLabel,
                        delta: _Delta.between(
                          fulfillmentRate * 100,
                          rate(prevReports) * 100,
                        ),
                        comparisonLabel: _comparisonLabel,
                        isLoading: isLoading,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.successLighter.withValues(
                              alpha: 0.7,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${reports.completedOrders}/${reports.totalOrders} orders',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              color: AppColors.successDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _ReportCard(
                        title: 'Sales Trend',
                        trailing: TextButton(
                          onPressed: () => _toast('Detailed view coming soon'),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            foregroundColor: AppColors.primary,
                          ),
                          child: const Text(
                            'View details',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        child: _SalesTrendChart(dailySales: reports.dailySales),
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle('Order Summary'),
                      const SizedBox(height: 10),
                      _OrderSummaryStrip(
                        reports: reports,
                        isLoading: isLoading,
                      ),
                      const SizedBox(height: 20),
                      const _SectionTitle('Top Performers'),
                      const SizedBox(height: 10),
                      _TopStaffCard(
                        stat: topStaff.isEmpty ? null : topStaff.first,
                        onTap: () => _showStaffDrilldown(topStaff),
                      ),
                      const SizedBox(height: 12),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _TopEntityCard(
                                icon: Icons.inventory_2_rounded,
                                iconColor: AppColors.primary,
                                iconBg: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                label: 'Top Product',
                                entity: _topProduct(reports),
                                onViewAll: () => _showProductDrilldown(reports),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TopEntityCard(
                                icon: Icons.groups_rounded,
                                iconColor: AppColors.success,
                                iconBg: AppColors.successLighter.withValues(
                                  alpha: 0.7,
                                ),
                                label: 'Top Customer',
                                entity: _topCustomer(reports),
                                onViewAll: () =>
                                    _showCustomerDrilldown(reports),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InsightsFooterTip(
                        exporting: _exporting,
                        onExport: () => _showExportSheet(reports),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _TopEntity? _topProduct(ReportsData reports) {
    final products = reports.productSales.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    if (products.isEmpty) return null;
    final p = products.first;
    return _TopEntity(
      name: p.name,
      subtitle: '${p.quantity} ${p.unit.productionWord}',
      value: _formatInsightRupee(p.revenue),
    );
  }

  _TopEntity? _topCustomer(ReportsData reports) {
    final customers = reports.customerRevenue.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    if (customers.isEmpty) return null;
    final c = customers.first;
    return _TopEntity(
      name: c.name,
      subtitle: '${c.orderCount} orders',
      value: _formatInsightRupee(c.revenue),
    );
  }
}

class _ReportsScreenHeader extends StatelessWidget {
  final VoidCallback? onDateRange;

  const _ReportsScreenHeader({this.onDateRange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track your business performance',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onDateRange != null)
            _ReportsHeaderActionButton(
              icon: Icons.calendar_month_rounded,
              tooltip: 'Date range',
              onPressed: onDateRange!,
            ),
        ],
      ),
    );
  }
}

class _ReportsHeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ReportsHeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }
}

/// Segmented preset switcher + the range / comparison row beneath it.
class _PeriodCard extends StatelessWidget {
  final String preset;
  final String rangeLabel;
  final String comparisonLabel;
  final _Comparison comparison;
  final ValueChanged<String> onPreset;
  final VoidCallback onDateRange;
  final ValueChanged<_Comparison> onComparisonChanged;

  const _PeriodCard({
    required this.preset,
    required this.rangeLabel,
    required this.comparisonLabel,
    required this.comparison,
    required this.onPreset,
    required this.onDateRange,
    required this.onComparisonChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
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
        children: [
          Row(
            children: [
              Expanded(
                child: _PresetPill(
                  label: 'Today',
                  selected: preset == _ReportsScreenState._kPresetToday,
                  onTap: () => onPreset(_ReportsScreenState._kPresetToday),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetPill(
                  label: '7 Days',
                  selected: preset == _ReportsScreenState._kPresetLast7,
                  onTap: () => onPreset(_ReportsScreenState._kPresetLast7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PresetPill(
                  label: 'Month',
                  selected: preset == _ReportsScreenState._kPresetThisMonth,
                  onTap: () => onPreset(_ReportsScreenState._kPresetThisMonth),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onDateRange,
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  icon: const Icon(Icons.calendar_today_rounded, size: 15),
                  label: Text(
                    rangeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              PopupMenuButton<_Comparison>(
                initialValue: comparison,
                onSelected: onComparisonChanged,
                tooltip: 'Compare against',
                position: PopupMenuPosition.under,
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _Comparison.previousPeriod,
                    child: Text('Previous period'),
                  ),
                  PopupMenuItem(
                    value: _Comparison.previousYear,
                    child: Text('Same period last year'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        comparisonLabel,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

/// Period-over-period change for one metric.
class _Delta {
  /// Null when there is no baseline to compare against.
  final double? percent;
  final bool lowerIsBetter;

  const _Delta(this.percent, {this.lowerIsBetter = false});

  factory _Delta.between(
    double current,
    double previous, {
    bool lowerIsBetter = false,
  }) {
    if (previous == 0) {
      return _Delta(current == 0 ? 0 : null, lowerIsBetter: lowerIsBetter);
    }
    return _Delta(
      (current - previous) / previous.abs() * 100,
      lowerIsBetter: lowerIsBetter,
    );
  }
}

class _DeltaLine extends StatelessWidget {
  final _Delta delta;
  final String comparisonLabel;

  const _DeltaLine({required this.delta, required this.comparisonLabel});

  @override
  Widget build(BuildContext context) {
    final pct = delta.percent;
    const captionStyle = TextStyle(
      color: AppColors.textLight,
      fontWeight: FontWeight.w600,
      fontSize: 11,
    );

    if (pct == null) {
      return Row(
        children: [
          const Text(
            'New',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              comparisonLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: captionStyle,
            ),
          ),
        ],
      );
    }

    final flat = pct.abs() < 0.05;
    final up = pct > 0;
    final good = flat ? false : (delta.lowerIsBetter ? !up : up);
    final color = flat
        ? AppColors.textLight
        : (good ? AppColors.success : AppColors.error);

    return Row(
      children: [
        if (!flat)
          Icon(
            up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
            size: 16,
            color: color,
          ),
        Text(
          '${pct.abs().toStringAsFixed(flat ? 0 : 1)}%',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            comparisonLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: captionStyle,
          ),
        ),
      ],
    );
  }
}

class _InsightKpiTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final _Delta delta;
  final String comparisonLabel;
  final Widget? trailing;
  final bool isLoading;

  const _InsightKpiTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.delta,
    required this.comparisonLabel,
    this.trailing,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (trailing != null && !isLoading) ...[
                const SizedBox(width: 6),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const DeliveroSkeleton(height: 24, width: 110)
          else
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.appTextStyles.sectionHeader.copyWith(
                fontSize: 24,
                letterSpacing: -0.8,
              ),
            ),
          const SizedBox(height: 8),
          if (!isLoading)
            _DeltaLine(delta: delta, comparisonLabel: comparisonLabel),
        ],
      ),
    );
  }
}

class _InsightsFooterTip extends StatelessWidget {
  final bool exporting;
  final VoidCallback onExport;

  const _InsightsFooterTip({required this.exporting, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(height: 2),
                Text(
                  'Export insights as CSV or PDF for the selected date range.',
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: exporting ? null : onExport,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            icon: exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: const Text(
              'Export',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  final List<DailySalesData> dailySales;
  const _SalesTrendChart({required this.dailySales});

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
    final maxY = (maxAmount <= 0 ? 100.0 : maxAmount * 1.2);
    final yInterval = maxY / 6;
    final lastIndex = dailySales.length - 1;

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: lastIndex.toDouble(),
          minY: 0,
          maxY: maxY,
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.primary,
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              getTooltipItems: (spots) => spots.map((spot) {
                final date = dailySales[spot.x.toInt()].date;
                return LineTooltipItem(
                  '${DateFormat('MMM d').format(date)}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(
                      text: '₹${NumberFormat.compact().format(spot.y)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= dailySales.length) {
                    return const SizedBox();
                  }
                  if (dailySales.length > 8 && index % 2 != 0) {
                    return const SizedBox();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      DateFormat('MMM d').format(dailySales[index].date),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
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
                reservedSize: 42,
                interval: yInterval,
                getTitlesWidget: (value, meta) => Text(
                  NumberFormat.compact().format(value),
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < dailySales.length; i++)
                  FlSpot(i.toDouble(), dailySales[i].amount),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                checkToShowDot: (spot, _) => spot.x == lastIndex.toDouble(),
                getDotPainter: (spot, percent, bar, index) =>
                    FlDotCirclePainter(
                      radius: 4.5,
                      color: AppColors.surface,
                      strokeWidth: 3,
                      strokeColor: AppColors.primary,
                    ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.28),
                    AppColors.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
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

class _TopStaffCard extends StatelessWidget {
  final _StaffStat? stat;
  final VoidCallback onTap;
  const _TopStaffCard({required this.stat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final stat = this.stat;
    if (stat == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          'Assign drivers to routes to see delivery stats here.',
          style: context.appTextStyles.body.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final pct = '${(stat.successRate * 100).clamp(0, 100).toStringAsFixed(1)}%';
    final initials = stat.name.trim().isEmpty
        ? '?'
        : stat.name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((p) => p[0].toUpperCase())
              .join();

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Delivery Team',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        stat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${stat.delivered}/${stat.total} delivered',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Success Rate',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pct,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successLighter.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Success',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopEntity {
  final String name;
  final String subtitle;
  final String value;

  const _TopEntity({
    required this.name,
    required this.subtitle,
    required this.value,
  });
}

class _TopEntityCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final _TopEntity? entity;
  final VoidCallback onViewAll;

  const _TopEntityCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.entity,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final entity = this.entity;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
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
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onViewAll,
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entity == null)
            const Text(
              'No data in range',
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            )
          else ...[
            Text(
              entity.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    entity.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  entity.value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderSummaryStrip extends StatelessWidget {
  final ReportsData reports;
  final bool isLoading;

  const _OrderSummaryStrip({required this.reports, required this.isLoading});

  String _pct(int part) {
    if (reports.totalOrders == 0) return '0%';
    return '${(part / reports.totalOrders * 100).round()}%';
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _OrderSummaryTile(
              icon: Icons.receipt_long_rounded,
              label: 'Total Orders',
              value: isLoading ? '—' : reports.totalOrders.toString(),
              color: AppColors.primary,
              background: AppColors.primary.withValues(alpha: 0.07),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OrderSummaryTile(
              icon: Icons.check_circle_rounded,
              label: 'Delivered',
              value: isLoading ? '—' : reports.completedOrders.toString(),
              share: isLoading ? null : _pct(reports.completedOrders),
              color: AppColors.success,
              background: AppColors.success.withValues(alpha: 0.07),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OrderSummaryTile(
              icon: Icons.schedule_rounded,
              label: 'Pending',
              value: isLoading ? '—' : reports.pendingOrders.toString(),
              share: isLoading ? null : _pct(reports.pendingOrders),
              color: AppColors.warning,
              background: AppColors.warning.withValues(alpha: 0.07),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _OrderSummaryTile(
              icon: Icons.cancel_rounded,
              label: 'Cancelled',
              value: isLoading ? '—' : reports.cancelledOrders.toString(),
              share: isLoading ? null : _pct(reports.cancelledOrders),
              color: AppColors.error,
              background: AppColors.error.withValues(alpha: 0.06),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? share;
  final Color color;
  final Color background;

  const _OrderSummaryTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
    this.share,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 8, 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.appTextStyles.sectionHeader.copyWith(
              color: color,
              fontSize: 20,
              letterSpacing: -0.4,
            ),
          ),
          if (share != null) ...[
            const SizedBox(height: 2),
            Text(
              share!,
              style: const TextStyle(
                color: AppColors.textLight,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
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
          const SizedBox(height: 12),
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
