import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../app/providers.dart';
import '../../../app/reports_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/models/driver.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  static const _kPresetToday = 'today';
  static const _kPresetLast7 = 'last7';
  static const _kPresetThisMonth = 'month';
  String _preset = _kPresetLast7;
  static const double _kTabBarHeight = 58;
  static const double _kHeaderHorizontalPadding = 24;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
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
          start:
              DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
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
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    final reports = isLoading ? ReportsData.empty() : _computeReports(inRange);
    final df = DateFormat('MMM d');
    final rangeLabel =
        '${df.format(_selectedDateRange.start)} — ${df.format(_selectedDateRange.end)}';
    final fulfillmentRate = reports.totalOrders == 0
        ? 0.0
        : reports.completedOrders / reports.totalOrders;
    final successRateLabel =
        '${(fulfillmentRate * 100).clamp(0, 100).toStringAsFixed(1)}%';
    final topStaff = _computeTopStaff(inRange, drivers);

    if (isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (noOrdersYet) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: const Icon(
                    Icons.analytics_rounded,
                    size: 64,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'No insights yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Create an order to see sales, products, and customer rankings here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: 220,
                  child: FilledButton.icon(
                    onPressed: () => context.push('/owner/orders/create'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text(
                      'Create order',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 240.0,
            floating: false,
            pinned: true,
            toolbarHeight: 0,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaryLighter.withValues(alpha: 0.35),
                          AppColors.backgroundPrimary,
                          AppColors.backgroundPrimary,
                        ],
                        stops: const [0.0, 0.65, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _kHeaderHorizontalPadding,
                  right: _kHeaderHorizontalPadding,
                  bottom: _kTabBarHeight + 18,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Insights',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _RangePill(
                              text: rangeLabel,
                              onTap: _selectDateRange,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Revenue, fulfillment, and customer performance',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.78,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 70,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            children: [
                              _KpiTile(
                                title: 'Revenue',
                                value:
                                    '₹${NumberFormat.compact().format(reports.totalRevenue)}',
                                icon: Icons.currency_rupee_rounded,
                                tone: _KpiTone.primary,
                              ),
                              const SizedBox(width: 10),
                              _KpiTile(
                                title: 'Pending',
                                value:
                                    '₹${NumberFormat.compact().format(reports.totalPendingRevenue)}',
                                icon: Icons.schedule_rounded,
                                tone: _KpiTone.warning,
                              ),
                              const SizedBox(width: 10),
                              _KpiTile(
                                title: 'Orders',
                                value: reports.totalOrders.toString(),
                                icon: Icons.receipt_long_rounded,
                                tone: _KpiTone.neutral,
                              ),
                              const SizedBox(width: 10),
                              _KpiTile(
                                title: 'Fulfillment',
                                value: '${(fulfillmentRate * 100).round()}%',
                                icon: Icons.check_circle_rounded,
                                tone: _KpiTone.success,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(_kTabBarHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      labelColor: AppColors.textPrimary,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      labelPadding: EdgeInsets.zero,
                      indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Products'),
                        Tab(text: 'Customers'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              _RefinedSummaryTab(
                reports: reports,
                successRateLabel: successRateLabel,
                preset: _preset,
                onPresetToday: () => _applyPreset(_kPresetToday),
                onPresetLast7: () => _applyPreset(_kPresetLast7),
                onPresetMonth: () => _applyPreset(_kPresetThisMonth),
                onExportCsv: () => _toast('CSV export coming soon', color: AppColors.info),
                onExportPdf: () => _toast('PDF export coming soon', color: AppColors.info),
                onDetailedSales: () => _toast('Detailed view coming soon'),
                driversLoaded: driversLoaded,
                staff: topStaff,
              ),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              _ProductsTab(productSales: reports.productSales),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              _CustomersTab(customerRevenue: reports.customerRevenue),
          ],
        ),
      ),
    );
  }
}

class _RefinedSummaryTab extends StatelessWidget {
  final ReportsData reports;
  final String successRateLabel;
  final String preset;
  final VoidCallback onPresetToday;
  final VoidCallback onPresetLast7;
  final VoidCallback onPresetMonth;
  final VoidCallback onExportCsv;
  final VoidCallback onExportPdf;
  final VoidCallback onDetailedSales;
  final bool driversLoaded;
  final List<_StaffStat> staff;

  const _RefinedSummaryTab({
    required this.reports,
    required this.successRateLabel,
    required this.preset,
    required this.onPresetToday,
    required this.onPresetLast7,
    required this.onPresetMonth,
    required this.onExportCsv,
    required this.onExportPdf,
    required this.onDetailedSales,
    required this.driversLoaded,
    required this.staff,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom + 96;
    final money = NumberFormat.decimalPattern();

    if (reports.totalOrders == 0) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
        child: _buildEmptyState(),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad),
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
                selected: preset == _ReportsScreenState._kPresetToday,
                onTap: onPresetToday,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PresetPill(
                label: 'Last 7 Days',
                selected: preset == _ReportsScreenState._kPresetLast7,
                onTap: onPresetLast7,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PresetPill(
                label: 'This Month',
                selected: preset == _ReportsScreenState._kPresetThisMonth,
                onTap: onPresetMonth,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _ExportChip(label: 'CSV', icon: Icons.table_chart_rounded, onTap: onExportCsv),
            const SizedBox(width: 10),
            _ExportChip(label: 'PDF', icon: Icons.picture_as_pdf_rounded, onTap: onExportPdf),
          ],
        ),
        const SizedBox(height: 14),
        _InsightStatCard(
          icon: Icons.payments_rounded,
          iconBg: AppColors.primaryLighter.withValues(alpha: 0.7),
          title: 'Total sales',
          value: '₹${money.format(reports.totalRevenue)}',
        ),
        const SizedBox(height: 12),
        _InsightStatCard(
          icon: Icons.account_balance_wallet_rounded,
          iconBg: AppColors.warningLighter.withValues(alpha: 0.8),
          title: 'Pending payments',
          value: '₹${money.format(reports.totalPendingRevenue)}',
        ),
        const SizedBox(height: 12),
        _InsightStatCard(
          icon: Icons.check_circle_rounded,
          iconBg: AppColors.successLighter.withValues(alpha: 0.8),
          title: 'Order success rate',
          value: successRateLabel,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            onPressed: onDetailedSales,
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
            onPressed: () {},
            icon: const Icon(Icons.tune_rounded),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: driversLoaded && staff.isEmpty
                ? const Text(
                    'No staff performance data yet.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : Column(
                    children: [
                      for (final s in staff.take(3)) ...[
                        _StaffRow(stat: s),
                        if (s != staff.take(3).last)
                          const Divider(height: 18, color: AppColors.divider),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
              const Text(
                'Optimize Your Fleet',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Our AI suggests actions in 2 minutes for the upcoming weekend — just to maintain your 98% success rate.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.4,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {},
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.textPrimary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.transparent : AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
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
  const _InsightStatCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.value,
    this.trailing,
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
          if (trailing != null) trailing!,
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
      return const Text(
        'No sales data for this period.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final last =
        dailySales.length > 7 ? dailySales.sublist(dailySales.length - 7) : dailySales;
    final maxValue =
        last.map((d) => d.amount).fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = (maxValue <= 0 ? 1.0 : maxValue) * 1.25;
    final groups = <BarChartGroupData>[
      for (var i = 0; i < last.length; i++)
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: last[i].amount,
              width: 14,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.primaryLight.withValues(alpha: i == last.length - 3 ? 1 : 0.6),
            ),
          ],
        ),
    ];

    String fmtDay(int i) {
      if (i < 0 || i >= last.length) return '';
      return DateFormat('EEE').format(last[i].date).toUpperCase();
    }

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      fmtDay(value.toInt()),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(enabled: false),
          barGroups: groups,
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

class _SummaryTab extends StatelessWidget {
  final ReportsData reports;
  const _SummaryTab({required this.reports});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom + 96;
    if (reports.totalOrders == 0) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
        child: _buildEmptyState(),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
      children: [
        _ReportCard(
          title: 'Sales Trend',
          child: _SalesTrendChart(dailySales: reports.dailySales),
        ),
        const SizedBox(height: 18),
        _ReportCard(
          title: 'Financial Liquidity',
          child: Column(
            children: [
              _StatRow(
                label: 'Gross Manifest Value',
                value:
                    '₹${NumberFormat.decimalPattern().format(reports.totalRevenue + reports.totalPendingRevenue)}',
                color: AppColors.textPrimary,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: AppColors.divider),
              ),
              _StatRow(
                label: 'Settled Revenue',
                value:
                    '₹${NumberFormat.decimalPattern().format(reports.totalRevenue)}',
                color: AppColors.success,
              ),
              const SizedBox(height: 12),
              _StatRow(
                label: 'Outstanding Receivables',
                value:
                    '₹${NumberFormat.decimalPattern().format(reports.totalPendingRevenue)}',
                color: AppColors.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ReportCard(
          title: 'Fulfillment Efficiency',
          child: Column(
            children: [
              _StatusDonutChart(statusCounts: reports.orderStatusBreakdown),
              const SizedBox(height: 32),
              Wrap(
                spacing: 20,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: reports.orderStatusBreakdown.keys.map((status) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _statusColor(status),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _ReportCard(
          title: 'Payment Mix',
          child: _PaymentMix(breakdown: reports.paymentMethodBreakdown),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _ProductsTab extends StatelessWidget {
  final Map<String, ProductSalesData> productSales;
  const _ProductsTab({required this.productSales});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom + 96;
    final sortedProducts = productSales.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    if (sortedProducts.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
      itemCount: sortedProducts.length,
      itemBuilder: (context, index) {
        final p = sortedProducts[index];
        return _RankingTile(
          rank: index + 1,
          title: p.name,
          subtitle: '${p.quantity} enterprise units distributed',
          value: '₹${NumberFormat.compact().format(p.revenue)}',
        );
      },
    );
  }
}

class _CustomersTab extends StatelessWidget {
  final Map<String, CustomerRevenueData> customerRevenue;
  const _CustomersTab({required this.customerRevenue});

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewPadding.bottom + 96;
    final sortedCustomers = customerRevenue.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    if (sortedCustomers.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad),
      itemCount: sortedCustomers.length,
      itemBuilder: (context, index) {
        final c = sortedCustomers[index];
        return _RankingTile(
          rank: index + 1,
          title: c.name,
          subtitle: '${c.orderCount} contractual transactions',
          value: '₹${NumberFormat.compact().format(c.revenue)}',
        );
      },
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  final List<DailySalesData> dailySales;
  const _SalesTrendChart({required this.dailySales});

  @override
  Widget build(BuildContext context) {
    if (dailySales.isEmpty) {
      return const Text(
        'No sales data available for this period.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final maxValue = dailySales
        .map((d) => d.amount)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = (maxValue <= 0 ? 1.0 : maxValue) * 1.2;
    final spots = <FlSpot>[
      for (var i = 0; i < dailySales.length; i++)
        FlSpot(i.toDouble(), dailySales[i].amount),
    ];

    String fmtDay(int i) {
      if (i < 0 || i >= dailySales.length) return '';
      return DateFormat('MMM d').format(dailySales[i].date);
    }

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: maxY / 4,
                getTitlesWidget: (value, meta) {
                  final label = NumberFormat.compact().format(value);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: (dailySales.length - 1) <= 0
                    ? 1
                    : (dailySales.length - 1) / 2,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  final isEdge = i == 0 || i == dailySales.length - 1;
                  final isMid =
                      dailySales.length >= 3 &&
                      i == ((dailySales.length - 1) / 2).round();
                  if (!isEdge && !isMid) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      fmtDay(i),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.22),
                    AppColors.primary.withValues(alpha: 0.0),
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

class _StatusDonutChart extends StatelessWidget {
  final Map<String, int> statusCounts;
  const _StatusDonutChart({required this.statusCounts});

  @override
  Widget build(BuildContext context) {
    if (statusCounts.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No order status data.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final entries = statusCounts.entries.where((e) => e.value > 0).toList();
    final total = entries.fold<int>(0, (a, e) => a + e.value);
    if (total == 0) {
      return const SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No order status data.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sectionsSpace: 6,
          centerSpaceRadius: 56,
          sections: entries.map((e) {
            final color = _statusColor(e.key);
            final pct = (e.value / total) * 100;
            return PieChartSectionData(
              value: e.value.toDouble(),
              title: pct >= 12 ? '${pct.round()}%' : '',
              color: color,
              radius: 26,
              titleStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _PaymentMix extends StatelessWidget {
  final Map<String, double> breakdown;
  const _PaymentMix({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final entries = breakdown.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries
        .fold<double>(0, (a, e) => a + e.value)
        .clamp(0.0, double.infinity);

    if (entries.isEmpty || total == 0) {
      return const Text(
        'No payment data available for this period.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    return Column(
      children: [
        for (final e in entries) ...[
          _PaymentMixRow(
            label: e.key.toUpperCase(),
            amount: e.value,
            fraction: e.value / total,
            color: _paymentMethodColor(e.key),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

Color _paymentMethodColor(String key) {
  final k = key.toLowerCase();
  if (k.contains('upi')) return AppColors.primary;
  if (k.contains('cash')) return AppColors.success;
  if (k.contains('card')) return AppColors.info;
  if (k.contains('online')) return AppColors.accent;
  return AppColors.textLight;
}

class _PaymentMixRow extends StatelessWidget {
  final String label;
  final double amount;
  final double fraction;
  final Color color;

  const _PaymentMixRow({
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (fraction * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '₹${NumberFormat.compact().format(amount)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$pct%',
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: AppColors.backgroundSecondary,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _ReportCard({
    required this.title,
    required this.child,
    this.trailing,
  });

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
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int rank;
  final String title;
  final String subtitle;
  final String value;

  const _RankingTile({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  color: rank <= 3
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String status) {
  final s = status.toLowerCase();
  if (s.contains('delivered')) return AppColors.success;
  if (s.contains('pending')) return AppColors.warning;
  if (s.contains('cancelled')) return AppColors.error;
  return AppColors.info;
}

Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(40),
          ),
          child: const Icon(
            Icons.analytics_rounded,
            size: 64,
            color: AppColors.textDisabled,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Insufficient data for selected period',
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Try changing the date range to see results.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

enum _KpiTone { primary, success, warning, neutral }

class _RangePill extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _RangePill({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: onTap == null
            ? AppColors.surface
            : AppColors.primaryLighter.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onTap == null
              ? AppColors.border
              : AppColors.primary.withValues(alpha: 0.25),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.date_range_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            Icons.unfold_more_rounded,
            size: 14,
            color: AppColors.textLight,
          ),
        ],
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: child,
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final _KpiTone tone;

  const _KpiTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent;
    final Color tint;
    switch (tone) {
      case _KpiTone.primary:
        accent = AppColors.primary;
        tint = AppColors.primaryLighter;
        break;
      case _KpiTone.success:
        accent = AppColors.success;
        tint = AppColors.successLighter;
        break;
      case _KpiTone.warning:
        accent = AppColors.warning;
        tint = AppColors.warningLighter;
        break;
      case _KpiTone.neutral:
        accent = AppColors.textPrimary;
        tint = AppColors.backgroundSecondary;
        break;
    }

    return Container(
      width: 176,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
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
