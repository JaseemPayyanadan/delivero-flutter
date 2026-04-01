import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../app/providers.dart';
import '../../../app/reports_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';

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
      setState(() => _selectedDateRange = picked);
    }
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
    final isLoading = !ordersLoaded && allOrders.isEmpty;
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
              _SummaryTab(reports: reports),
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
  const _ReportCard({required this.title, required this.child});

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
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textLight,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
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
