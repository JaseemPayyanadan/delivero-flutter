import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/reports_provider.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/order.dart';

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(reportsProvider);
    final orders = ref.watch(ordersProvider);
    final customers = ref.watch(customersProvider);
    final drivers = ref.watch(driversProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final routes = ref.watch(routesProvider);
    final user = ref.watch(authProvider).user;
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final customersLoaded = ref.watch(customersLoadedProvider);
    final driversLoaded = ref.watch(driversLoadedProvider);
    final foodItemsLoaded = ref.watch(foodItemsLoadedProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);

    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM').format(now);
    final shortDateStr = DateFormat('EEE, d MMM').format(now);
    final totalRevenue = reports.totalRevenue + reports.totalPendingRevenue;
    final fulfillmentRate = reports.totalOrders == 0
        ? 0.0
        : reports.completedOrders / reports.totalOrders;
    final todayOrdersCount = orders.where((o) {
      return o.orderDate.year == now.year &&
          o.orderDate.month == now.month &&
          o.orderDate.day == now.day;
    }).length;

    final bool isEmpty =
        customers.isEmpty &&
        drivers.isEmpty &&
        foodItems.isEmpty &&
        routes.isEmpty &&
        orders.isEmpty;
    final bool isLoading =
        !(ordersLoaded &&
            customersLoaded &&
            driversLoaded &&
            foodItemsLoaded &&
            routesLoaded);

    final displayName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name.trim()
        : 'Owner';
    final greeting = 'Hello, $displayName (Owner)';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: isEmpty ? 170.0 : 280.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 0,
            automaticallyImplyLeading: false,
            systemOverlayStyle: AppTheme.systemOverlayStyle.copyWith(
              statusBarColor: AppColors.primaryLighter.withValues(alpha: 0.35),
            ),
            flexibleSpace: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primaryLighter.withValues(alpha: 0.42),
                          AppColors.backgroundPrimary,
                          AppColors.backgroundPrimary,
                        ],
                        stops: const [0.0, 0.62, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 16,
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                greeting,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.9,
                                  ),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            _HeaderIconButton(
                              icon: Icons.notifications_none_rounded,
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Notifications coming soon',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppColors.secondary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Dashboard',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            _HeaderPill(text: shortDateStr.toUpperCase()),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!isEmpty) ...[
                          const SizedBox(height: 14),
                          _KpiStrip(
                            children: [
                              _KpiCard(
                                title: 'Revenue',
                                value:
                                    '₹${NumberFormat.compact().format(totalRevenue)}',
                                icon: Icons.currency_rupee_rounded,
                                tone: _KpiTone.primary,
                              ),
                              _KpiCard(
                                title: 'Orders Today',
                                value: todayOrdersCount.toString(),
                                icon: Icons.today_rounded,
                                tone: _KpiTone.neutral,
                              ),
                              _KpiCard(
                                title: 'Customers',
                                value: customers.length.toString(),
                                icon: Icons.people_alt_rounded,
                                tone: _KpiTone.warning,
                              ),
                              _KpiCard(
                                title: 'Fulfillment',
                                value: '${(fulfillmentRate * 100).round()}%',
                                icon: Icons.check_circle_rounded,
                                tone: _KpiTone.success,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isEmpty && isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(context),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    _QuickActionsRow(
                      actions: [
                        _QuickAction(
                          label: 'New Order',
                          icon: Icons.add_shopping_cart_rounded,
                          color: AppColors.primary,
                          path: '/owner/orders/create',
                        ),
                        _QuickAction(
                          label: 'Customers',
                          icon: Icons.business_rounded,
                          color: AppColors.success,
                          path: '/owner/customers',
                        ),
                        _QuickAction(
                          label: 'Routes',
                          icon: Icons.alt_route_rounded,
                          color: AppColors.info,
                          path: '/owner/routes',
                        ),
                        _QuickAction(
                          label: 'Drivers',
                          icon: Icons.person_add_alt_1_rounded,
                          color: AppColors.secondary,
                          path: '/owner/routes?tab=drivers',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _DashboardSection(
                      title: 'Sales Revenue',
                      trailingText: 'This Week',
                      child: _SalesTrendBars(dailySales: reports.dailySales),
                    ),
                    const SizedBox(height: 28),
                    _DashboardSection(
                      title: 'Recent Orders',
                      subtitle: 'Latest transactions across all accounts',
                      trailingText: 'View all',
                      onTrailingTap: () => context.push('/owner/orders'),
                      child: _RecentOrdersList(orders: orders),
                    ),
                    const SizedBox(height: 28),
                    _DashboardSection(
                      title: 'Product Mix',
                      subtitle: 'Revenue distribution across catalog',
                      child: _ProductSaleChart(
                        productSales: reports.productSales,
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                ),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.dashboard_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Ready to Build Your Dashboard?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Get started by adding customers, products, routes, and creating your first order',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _EmptyStateFeature(
                  icon: Icons.people_alt_rounded,
                  label: 'Customers',
                ),
                _EmptyStateFeature(
                  icon: Icons.inventory_2_rounded,
                  label: 'Products',
                ),
                _EmptyStateFeature(
                  icon: Icons.alt_route_rounded,
                  label: 'Routes',
                ),
                _EmptyStateFeature(
                  icon: Icons.receipt_long_rounded,
                  label: 'Orders',
                ),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/owner/customers'),
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'Add your first customer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _KpiTone { primary, success, warning, neutral }

class _HeaderPill extends StatelessWidget {
  final String text;
  const _HeaderPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 22),
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  final List<Widget> children;
  const _KpiStrip({required this.children});

  @override
  Widget build(BuildContext context) {
    final items = children.length > 4 ? children.take(4).toList() : children;
    if (items.length <= 2) {
      return Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: items[i]),
            if (i != items.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: items[0]),
            const SizedBox(width: 12),
            Expanded(child: items[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: items[2]),
            const SizedBox(width: 12),
            Expanded(child: items[3]),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final _KpiTone tone;

  const _KpiCard({
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
        accent = AppColors.secondary;
        tint = AppColors.backgroundSecondary;
        break;
    }

    return Container(
      height: 104,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final String path;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.path,
  });
}

class _QuickActionsRow extends StatelessWidget {
  final List<_QuickAction> actions;
  const _QuickActionsRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
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
          for (var i = 0; i < actions.length; i++)
            Expanded(child: _QuickActionTile(action: actions[i])),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionTile({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(action.path),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(action.icon, color: action.color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductSaleChart extends StatelessWidget {
  final Map<String, ProductSalesData> productSales;

  const _ProductSaleChart({required this.productSales});

  @override
  Widget build(BuildContext context) {
    final sortedSales = productSales.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final displaySales = sortedSales.take(5).toList();

    if (displaySales.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No sales data yet',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
            ),
          ),
        ),
      );
    }

    final totalRevenue = sortedSales.fold<double>(0, (sum, e) => sum + e.revenue);
    final topRevenue = displaySales.first.revenue;
    final maxY = (topRevenue <= 0 ? 1.0 : topRevenue) * 1.25;
    const barPalette = <Color>[
      AppColors.primary,
      AppColors.info,
      AppColors.success,
      AppColors.warning,
      AppColors.secondary,
    ];

    return Container(
      height: 240,
      padding: const EdgeInsets.all(24),
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
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppColors.divider, strokeWidth: 1),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              tooltipBorderRadius: BorderRadius.circular(12),
              tooltipMargin: 10,
              maxContentWidth: 220,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) =>
                  AppColors.textPrimary.withValues(alpha: 0.92),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (groupIndex < 0 || groupIndex >= displaySales.length) {
                  return null;
                }
                final item = displaySales[groupIndex];
                final pct = totalRevenue <= 0 ? 0.0 : (item.revenue / totalRevenue);
                final revenueStr = '₹${NumberFormat.compact().format(item.revenue)}';
                return BarTooltipItem(
                  '${item.name}\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    height: 1.2,
                  ),
                  children: [
                    TextSpan(
                      text: '$revenueStr  •  ${(pct * 100).toStringAsFixed(1)}%\n',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                    TextSpan(
                      text: 'Qty: ${item.quantity}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        height: 1.3,
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
                reservedSize: 46,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= displaySales.length) {
                    return const SizedBox();
                  }
                  final name = displaySales[value.toInt()].name;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Transform.rotate(
                      angle: -0.42, // ~-24deg for readability
                      alignment: Alignment.topLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textLight,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  final label = value == 0
                      ? '0'
                      : '₹${NumberFormat.compact().format(value)}';
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      label,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
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
          borderData: FlBorderData(show: false),
          barGroups: displaySales.asMap().entries.map((e) {
            final color = barPalette[e.key % barPalette.length];
            return BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.revenue,
                  width: 18,
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      color.withValues(alpha: 0.55),
                      color,
                    ],
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

class _EmptyStateFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EmptyStateFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textLight, size: 24),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }
}

class _DashboardSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTrailingTap;
  final Widget child;

  const _DashboardSection({
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTrailingTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  if (trailingText != null) ...[
                    const SizedBox(width: 12),
                    InkWell(
                      onTap: onTrailingTap,
                      borderRadius: BorderRadius.circular(999),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Text(
                          trailingText!,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class _SalesTrendBars extends StatelessWidget {
  final List<DailySalesData> dailySales;
  const _SalesTrendBars({required this.dailySales});

  @override
  Widget build(BuildContext context) {
    final last = dailySales.length > 7
        ? dailySales.sublist(dailySales.length - 7)
        : dailySales;
    if (last.isEmpty) {
      return Container(
        height: 220,
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
        child: const Center(
          child: Text(
            'No revenue data yet',
            style: TextStyle(
              color: AppColors.textLight,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    final maxValue = last
        .map((d) => d.amount)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = (maxValue <= 0 ? 1.0 : maxValue) * 1.25;
    final highlightIndex = _pickHighlightIndex(last);

    return Container(
      height: 240,
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
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
          barTouchData: BarTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipMargin: 10,
              maxContentWidth: 120,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (_) =>
                  AppColors.textPrimary.withValues(alpha: 0.92),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (groupIndex != highlightIndex) return null;
                final val = rod.toY;
                final label = '₹${NumberFormat.compact().format(val)}';
                return BarTooltipItem(
                  label,
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 0.2,
                  ),
                );
              },
            ),
          ),
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
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= last.length) return const SizedBox.shrink();
                  final isHighlight = i == highlightIndex;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      DateFormat('EEE').format(last[i].date).toUpperCase(),
                      style: TextStyle(
                        color: isHighlight
                            ? AppColors.textPrimary
                            : AppColors.textLight,
                        fontSize: 10,
                        fontWeight:
                            isHighlight ? FontWeight.w900 : FontWeight.w800,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < last.length; i++)
              BarChartGroupData(
                x: i,
                showingTooltipIndicators:
                    i == highlightIndex ? const [0] : const [],
                barRods: [
                  BarChartRodData(
                    toY: last[i].amount,
                    width: 14,
                    borderRadius: BorderRadius.circular(10),
                    color: i == highlightIndex
                        ? AppColors.primary
                        : AppColors.backgroundSecondary.withValues(alpha: 0.9),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  int _pickHighlightIndex(List<DailySalesData> last) {
    final thuIndex = last.indexWhere((d) => d.date.weekday == DateTime.thursday);
    if (thuIndex != -1) return thuIndex;
    if (last.isEmpty) return 0;
    var maxIdx = 0;
    var maxVal = last.first.amount;
    for (var i = 1; i < last.length; i++) {
      final v = last[i].amount;
      if (v > maxVal) {
        maxVal = v;
        maxIdx = i;
      }
    }
    return maxIdx;
  }
}

class _RecentOrdersList extends StatelessWidget {
  final List<Order> orders;

  const _RecentOrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    final recentOrders = orders.toList()
      ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
    final displayOrders = recentOrders.take(5).toList();

    if (displayOrders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'No recent orders',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        ...displayOrders.map((order) => _RecentOrderTile(order: order)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.push('/owner/orders'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'View all orders',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.2,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final Order order;

  const _RecentOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: () => context.push('/owner/orders/${order.id}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.receipt_outlined,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: Text(
          order.customerName,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          DateFormat('MMM d, hh:mm a').format(order.orderDate),
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '₹${NumberFormat.decimalPattern().format(order.totalAmount)}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              order.status.name.toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: _getStatusColor(order.status),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }
}
