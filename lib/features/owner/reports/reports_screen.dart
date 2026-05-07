import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../app/providers.dart';
import '../../../app/reports_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../core/widgets/delivero_skeleton.dart';
import '../../../data/models/order.dart';
import '../../../data/models/driver.dart';

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

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
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

  ReportsData _computeReports(List<Order> orders) {
    if (orders.isEmpty) return ReportsData.empty();

    double totalRevenue = 0;
    double totalPendingRevenue = 0;
    int completedOrders = 0;
    int pendingOrders = 0;
    int cancelledOrders = 0;
    final Map<String, double> paymentMethodBreakdown = {};
    final Map<String, int> orderStatusBreakdown = {};
    final Map<DateTime, DailySalesData> dailyMap = {};
    final Map<String, ProductSalesData> productSalesMap = {};
    final Map<String, CustomerRevenueData> customerRevenueMap = {};

    for (final order in orders) {
      if (order.paymentStatus == PaymentStatus.paid) {
        totalRevenue += order.totalAmount;
      } else if (order.paymentStatus == PaymentStatus.partial) {
        totalRevenue += (order.amountPaid ?? 0);
        totalPendingRevenue += (order.totalAmount - (order.amountPaid ?? 0));
      } else {
        totalPendingRevenue += order.totalAmount;
      }

      if (order.status == OrderStatus.delivered) {
        completedOrders++;
      } else if (order.status == OrderStatus.pending) {
        pendingOrders++;
      } else if (order.status == OrderStatus.cancelled) {
        cancelledOrders++;
      }

      final pm = order.paymentMethod?.name ?? 'unknown';
      paymentMethodBreakdown[pm] =
          (paymentMethodBreakdown[pm] ?? 0) + order.totalAmount;

      final status = order.status.name;
      orderStatusBreakdown[status] = (orderStatusBreakdown[status] ?? 0) + 1;

      for (final item in order.items) {
        final existing = productSalesMap[item.foodItemName];
        if (existing != null) {
          productSalesMap[item.foodItemName] = ProductSalesData(
            name: item.foodItemName,
            quantity: existing.quantity + item.quantity,
            revenue: existing.revenue + item.totalPrice,
          );
        } else {
          productSalesMap[item.foodItemName] = ProductSalesData(
            name: item.foodItemName,
            quantity: item.quantity,
            revenue: item.totalPrice,
          );
        }
      }

      final custExisting = customerRevenueMap[order.customerName];
      if (custExisting != null) {
        customerRevenueMap[order.customerName] = CustomerRevenueData(
          name: order.customerName,
          revenue: custExisting.revenue + order.totalAmount,
          orderCount: custExisting.orderCount + 1,
        );
      } else {
        customerRevenueMap[order.customerName] = CustomerRevenueData(
          name: order.customerName,
          revenue: order.totalAmount,
          orderCount: 1,
        );
      }

      final date = DateTime(
        order.orderDate.year,
        order.orderDate.month,
        order.orderDate.day,
      );
      if (dailyMap.containsKey(date)) {
        final existing = dailyMap[date]!;
        dailyMap[date] = DailySalesData(
          date: date,
          amount: existing.amount + order.totalAmount,
          count: existing.count + 1,
        );
      } else {
        dailyMap[date] = DailySalesData(
          date: date,
          amount: order.totalAmount,
          count: 1,
        );
      }
    }

    final dailySales = dailyMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final avgOrderValue = totalRevenue / (orders.isEmpty ? 1 : orders.length);

    return ReportsData(
      totalRevenue: totalRevenue,
      totalPendingRevenue: totalPendingRevenue,
      totalOrders: orders.length,
      completedOrders: completedOrders,
      pendingOrders: pendingOrders,
      cancelledOrders: cancelledOrders,
      paymentMethodBreakdown: paymentMethodBreakdown,
      orderStatusBreakdown: orderStatusBreakdown,
      dailySales: dailySales,
      averageOrderValue: avgOrderValue,
      productSales: productSalesMap,
      customerRevenue: customerRevenueMap,
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
        : _computeReports(inRange);
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
          children: [
            const Text(
              'Performance Insights',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Analyze your delivery metrics and financial trends',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _PresetPill(
                    label: 'Today',
                    selected: _preset == _kPresetToday,
                    onTap: () => _applyPreset(_kPresetToday),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PresetPill(
                    label: 'Last 7 Days',
                    selected: _preset == _kPresetLast7,
                    onTap: () => _applyPreset(_kPresetLast7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PresetPill(
                    label: 'This Month',
                    selected: _preset == _kPresetThisMonth,
                    onTap: () => _applyPreset(_kPresetThisMonth),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _ExportChip(
                  label: 'CSV',
                  icon: Icons.table_chart_rounded,
                  onTap: () =>
                      _toast('CSV export coming soon', color: AppColors.info),
                ),
                const SizedBox(width: 10),
                _ExportChip(
                  label: 'PDF',
                  icon: Icons.picture_as_pdf_rounded,
                  onTap: () =>
                      _toast('PDF export coming soon', color: AppColors.info),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    rangeLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InsightStatCard(
              icon: Icons.payments_rounded,
              iconBg: AppColors.primaryLighter.withValues(alpha: 0.7),
              title: 'Total sales',
              isLoading: isLoading,
              value:
                  '₹${NumberFormat.decimalPattern().format(reports.totalRevenue)}',
            ),
            const SizedBox(height: 12),
            _InsightStatCard(
              icon: Icons.account_balance_wallet_rounded,
              iconBg: AppColors.warningLighter.withValues(alpha: 0.8),
              title: 'Pending payments',
              isLoading: isLoading,
              value:
                  '₹${NumberFormat.decimalPattern().format(reports.totalPendingRevenue)}',
            ),
            const SizedBox(height: 12),
            _InsightStatCard(
              icon: Icons.check_circle_rounded,
              iconBg: AppColors.successLighter.withValues(alpha: 0.8),
              title: 'Order success rate',
              isLoading: isLoading,
              value: successRateLabel,
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Stable',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ReportCard(
              title: 'Sales Trend',
              trailing: TextButton(
                onPressed: () => _toast('Detailed view coming soon'),
                child: const Text('Detailed View'),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: _SalesBarChart(dailySales: reports.dailySales),
              ),
            ),
            const SizedBox(height: 16),
            _ReportCard(
              title: 'Top Delivery Staff',
              trailing: IconButton(
                tooltip: 'Filter',
                onPressed: () => _toast('Filter coming soon'),
                icon: const Icon(Icons.tune_rounded),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: driversLoaded && topStaff.isEmpty
                    ? const Text(
                        'No staff performance data yet.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
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
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'View all staff performance',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowDeep,
                    blurRadius: 24,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Optimize Your Fleet',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Our AI suggests actions in 2 minutes for the upcoming weekend — just to maintain your 98% success rate.',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimary.withValues(alpha: 0.9),
                      height: 1.4,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _toast('Upgrade coming soon'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Upgrade logistics',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surface,
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
              fontWeight: FontWeight.w800,
              fontSize: 12,
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
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

class _InsightStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String value;
  final Widget? trailing;
  final bool isLoading;

  const _InsightStatCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
    this.trailing,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textLight,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                if (isLoading)
                  const DeliveroSkeleton(height: 20, width: 100)
                else
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null && !isLoading) trailing!,
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

class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _ReportCard({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textLight,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}
