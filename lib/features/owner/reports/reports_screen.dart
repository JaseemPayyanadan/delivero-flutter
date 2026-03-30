import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../app/providers.dart';
import '../../../app/reports_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui_kit.dart';
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

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final reports = _computeReportsForRange(orders, _selectedDateRange);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 160.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Business Intelligence',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    'Data-driven insights for your enterprise',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              background: Container(color: AppColors.backgroundPrimary),
            ),
            actions: [
              IconButton(
                onPressed: _selectDateRange,
                icon: UiCard(
                  radius: 14,
                  padding: const EdgeInsets.all(8),
                  color: AppColors.backgroundSecondary,
                  boxShadow: const [],
                  child: const Icon(
                    Icons.date_range_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  _buildDateRangeIndicator(),
                  const SizedBox(height: 24),
                  _buildTabSelector(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _SummaryTab(reports: reports),
                _ProductsTab(productSales: reports.productSales),
                _CustomersTab(customerRevenue: reports.customerRevenue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ReportsData _computeReportsForRange(
    List<Order> orders,
    DateTimeRange dateRange,
  ) {
    if (orders.isEmpty) return ReportsData.empty();

    final start = DateTime(
      dateRange.start.year,
      dateRange.start.month,
      dateRange.start.day,
    );
    final endExclusive = DateTime(
      dateRange.end.year,
      dateRange.end.month,
      dateRange.end.day,
    ).add(const Duration(days: 1));

    double totalRevenue = 0;
    double totalPendingRevenue = 0;
    int completedOrders = 0;
    int pendingOrders = 0;
    int cancelledOrders = 0;
    final paymentMethodBreakdown = <String, double>{};
    final orderStatusBreakdown = <String, int>{};
    final dailyMap = <DateTime, DailySalesData>{};
    final productSalesMap = <String, ProductSalesData>{};
    final customerRevenueMap = <String, CustomerRevenueData>{};

    int totalOrders = 0;

    for (final order in orders) {
      final date = DateTime(
        order.orderDate.year,
        order.orderDate.month,
        order.orderDate.day,
      );
      if (date.isBefore(start) || !date.isBefore(endExclusive)) continue;

      totalOrders++;

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

    if (totalOrders == 0) return ReportsData.empty();

    final dailySales = dailyMap.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final avgOrderValue = totalRevenue / (totalOrders == 0 ? 1 : totalOrders);

    return ReportsData(
      totalRevenue: totalRevenue,
      totalPendingRevenue: totalPendingRevenue,
      totalOrders: totalOrders,
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

  Widget _buildDateRangeIndicator() {
    final df = DateFormat('MMM d, yyyy');
    return InkWell(
      onTap: _selectDateRange,
      borderRadius: BorderRadius.circular(20),
      child: UiCard(
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.textLight,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${df.format(_selectedDateRange.start)} - ${df.format(_selectedDateRange.end)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.unfold_more_rounded,
              color: AppColors.textLight,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 12,
          letterSpacing: 0.3,
        ),
        tabs: const [
          Tab(height: 42, text: 'OVERVIEW'),
          Tab(height: 42, text: 'PRODUCTS'),
          Tab(height: 42, text: 'CUSTOMERS'),
        ],
      ),
    );
  }
}

class _SummaryTab extends StatelessWidget {
  final ReportsData reports;
  const _SummaryTab({required this.reports});

  @override
  Widget build(BuildContext context) {
    final gross = reports.totalRevenue + reports.totalPendingRevenue;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      children: [
        _KpiGrid(reports: reports),
        const SizedBox(height: 16),
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UiSectionHeader(
                title: 'Revenue Trend',
                subtitle: 'Daily gross sales for the selected period',
              ),
              const SizedBox(height: 16),
              _RevenueTrendChart(dailySales: reports.dailySales),
            ],
          ),
        ),
        const SizedBox(height: 16),
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UiSectionHeader(
                title: 'Collection',
                subtitle: 'Settled vs outstanding receivables',
              ),
              const SizedBox(height: 16),
              _StatRow(
                label: 'Gross',
                value: '₹${NumberFormat.compact().format(gross)}',
                color: AppColors.textPrimary,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Divider(height: 1, color: AppColors.divider),
              ),
              _StatRow(
                label: 'Settled',
                value:
                    '₹${NumberFormat.compact().format(reports.totalRevenue)}',
                color: AppColors.success,
              ),
              const SizedBox(height: 10),
              _StatRow(
                label: 'Outstanding',
                value:
                    '₹${NumberFormat.compact().format(reports.totalPendingRevenue)}',
                color: AppColors.error,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        UiCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UiSectionHeader(
                title: 'Order Status',
                subtitle: 'Fulfillment breakdown',
              ),
              const SizedBox(height: 16),
              _OrderStatusDonut(breakdown: reports.orderStatusBreakdown),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProductsTab extends StatelessWidget {
  final Map<String, ProductSalesData> productSales;
  const _ProductsTab({required this.productSales});

  @override
  Widget build(BuildContext context) {
    final sortedProducts = productSales.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    if (sortedProducts.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
    final sortedCustomers = customerRevenue.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    if (sortedCustomers.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
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

class _KpiGrid extends StatelessWidget {
  final ReportsData reports;

  const _KpiGrid({required this.reports});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _KpiCard(
          label: 'Orders',
          value: reports.totalOrders.toString(),
          color: AppColors.primary,
        ),
        _KpiCard(
          label: 'Delivered',
          value: reports.completedOrders.toString(),
          color: AppColors.success,
        ),
        _KpiCard(
          label: 'Pending',
          value: reports.pendingOrders.toString(),
          color: AppColors.warning,
        ),
        _KpiCard(
          label: 'Avg Order',
          value: '₹${NumberFormat.compact().format(reports.averageOrderValue)}',
          color: AppColors.secondary,
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return UiCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueTrendChart extends StatelessWidget {
  final List<DailySalesData> dailySales;

  const _RevenueTrendChart({required this.dailySales});

  @override
  Widget build(BuildContext context) {
    if (dailySales.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Text(
            'No data for this period',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final maxY = dailySales
        .map((e) => e.amount)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final points = <FlSpot>[];
    for (var i = 0; i < dailySales.length; i++) {
      points.add(FlSpot(i.toDouble(), dailySales[i].amount));
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY == 0 ? 1 : maxY / 4,
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: dailySales.length <= 6
                    ? 1
                    : (dailySales.length / 5).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= dailySales.length) {
                    return const SizedBox.shrink();
                  }
                  final d = dailySales[idx].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('d MMM').format(d),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: points,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusDonut extends StatelessWidget {
  final Map<String, int> breakdown;

  const _OrderStatusDonut({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    if (breakdown.isEmpty) return _buildEmptyState();
    final total = breakdown.values.fold<int>(0, (a, b) => a + b);
    final entries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        SizedBox(
          height: 210,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 64,
              sections: entries.map((e) {
                final color = _getStatusColor(e.key);
                final pct = total == 0 ? 0 : (e.value / total) * 100;
                return PieChartSectionData(
                  value: e.value.toDouble(),
                  title: pct >= 12 ? '${pct.toStringAsFixed(0)}%' : '',
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
        ),
        const SizedBox(height: 14),
        ...entries.map((e) {
          final color = _getStatusColor(e.key);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    e.key.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  '${e.value}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('delivered')) return AppColors.success;
    if (s.contains('pending')) return AppColors.warning;
    if (s.contains('cancelled')) return AppColors.error;
    return AppColors.info;
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: UiCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: rank <= 3
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(14),
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
            const SizedBox(width: 14),
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
      ),
    );
  }
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
      ],
    ),
  );
}
