import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../app/reports_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/ui_kit.dart';

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
    final reports = ref.watch(reportsProvider);

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
    return UiCard(
      radius: 20,
      padding: const EdgeInsets.all(6),
      color: AppColors.backgroundSecondary,
      boxShadow: const [],
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        tabs: const [
          Tab(text: 'OVERVIEW'),
          Tab(text: 'PRODUCTS'),
          Tab(text: 'CUSTOMERS'),
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
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
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
        const SizedBox(height: 24),
        _ReportCard(
          title: 'Fulfillment Efficiency',
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 6,
                    centerSpaceRadius: 50,
                    sections: reports.orderStatusBreakdown.entries.map((e) {
                      final color = _getStatusColor(e.key);
                      return PieChartSectionData(
                        value: e.value.toDouble(),
                        title: '${e.value}',
                        color: color,
                        radius: 24,
                        titleStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
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
                          color: _getStatusColor(status),
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
        const SizedBox(height: 40),
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

class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ReportCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 30,
            offset: Offset(0, 15),
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
