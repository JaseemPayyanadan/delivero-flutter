import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/reports_provider.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/order.dart';

Future<void> _refreshOwnerDashboard(WidgetRef ref) async {
  await Future.wait([
    ref.read(ordersProvider.notifier).refresh(),
    ref.read(customersProvider.notifier).refresh(),
    ref.read(foodItemsProvider.notifier).refresh(),
    ref.read(routesProvider.notifier).refresh(),
    ref.read(driversProvider.notifier).refresh(),
  ]);
}

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
    final greeting = 'Hello, $displayName';
    // Use viewPadding (not padding) for top inset: on edge-to-edge layouts padding can
    // be 0 while the status bar / notch still occupies space — a few px mismatch clips
    // the header. SliverAppBar also defaults to hard clipping unless disabled below.
    final safeTop = MediaQuery.viewPaddingOf(context).top;
    // flexibleSpace content is bottom-aligned in a Stack; if expandedHeight is too
    // small, the Column overflows upward and the top clips.
    final expandedHeaderHeight = isEmpty
        ? (safeTop + 128.0).clamp(192.0, 264.0)
        : (safeTop + 468.0).clamp(380.0, 640.0);
    final bottomInset =
        MediaQuery.paddingOf(context).bottom + 100; // nav bar + home indicator

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: RefreshIndicator(
        color: AppColors.primary,
        displacement: 48,
        onRefresh: () => _refreshOwnerDashboard(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              expandedHeight: expandedHeaderHeight,
              floating: false,
              pinned: true,
              clipBehavior: Clip.none,
              backgroundColor: AppColors.backgroundPrimary,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 0,
              automaticallyImplyLeading: false,
              systemOverlayStyle: AppTheme.systemOverlayStyle.copyWith(
                statusBarColor: AppColors.primaryLighter.withValues(
                  alpha: 0.35,
                ),
              ),
              flexibleSpace: Stack(
                clipBehavior: Clip.none,
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
                    child: Padding(
                      padding: EdgeInsets.only(top: safeTop),
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
                                icon: Icons.search_rounded,
                                showBadge: false,
                                tooltip: 'Search orders & customers',
                                onTap: () => context.push('/owner/search'),
                              ),
                              const SizedBox(width: 4),
                              _HeaderIconButton(
                                icon: Icons.notifications_none_rounded,
                                showBadge: true,
                                tooltip: 'Notifications',
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Push alerts are on when you allow '
                                        'notifications. Server can target your '
                                        'device via FCM.',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                      backgroundColor: AppColors.secondary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      action: SnackBarAction(
                                        label: 'OK',
                                        textColor: Colors.white70,
                                        onPressed: () {},
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
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
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
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
                              ),
                              const SizedBox(width: 12),
                              _HeaderPill(text: shortDateStr.toUpperCase()),
                            ],
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
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Loading your workspace…',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.95,
                            ),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pull down anytime to refresh.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textLight.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
                      SizedBox(height: bottomInset),
                    ],
                  ),
                ),
              ),
          ],
        ),
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
            const SizedBox(height: 28),
            Text(
              'Tip: pull down on this screen anytime to refresh data.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textLight.withValues(alpha: 0.95),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/owner/customers');
                },
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
  final bool showBadge;
  final String? tooltip;

  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.showBadge = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 10,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              if (showBadge)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
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
      constraints: const BoxConstraints(minHeight: 100),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
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
    return Tooltip(
      message: action.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push(action.path);
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
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
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductSaleChart extends StatelessWidget {
  final Map<String, ProductSalesData> productSales;

  const _ProductSaleChart({required this.productSales});

  static const List<Color> _barPalette = [
    AppColors.primary,
    AppColors.info,
    AppColors.success,
    AppColors.warning,
    AppColors.secondary,
  ];

  @override
  Widget build(BuildContext context) {
    final sortedSales = productSales.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final displaySales = sortedSales.take(5).toList();

    if (displaySales.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.stacked_bar_chart_rounded,
                color: AppColors.textLight,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No product mix yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'When orders include line items, revenue share by product appears here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      );
    }

    final catalogTotal = sortedSales.fold<double>(
      0,
      (sum, e) => sum + e.revenue,
    );
    final topFiveTotal = displaySales.fold<double>(
      0,
      (sum, e) => sum + e.revenue,
    );
    final topRevenue = displaySales.first.revenue;
    final maxY = (topRevenue <= 0 ? 1.0 : topRevenue) * 1.22;
    final yInterval = maxY > 0 ? maxY / 4 : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sortedSales.length > 5)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Showing top 5 by revenue · ${sortedSales.length} products in catalog',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '₹${NumberFormat.compact().format(topFiveTotal)} in view',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (catalogTotal > 0)
                    Text(
                      catalogTotal > topFiveTotal
                          ? '${((topFiveTotal / catalogTotal) * 100).round()}% of catalog revenue'
                          : '100% of catalog revenue',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textLight,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 196,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: AppColors.divider, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        direction: TooltipDirection.top,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        tooltipBorderRadius: BorderRadius.circular(12),
                        tooltipMargin: 8,
                        maxContentWidth: 240,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipColor: (_) =>
                            AppColors.textPrimary.withValues(alpha: 0.94),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (groupIndex < 0 ||
                              groupIndex >= displaySales.length) {
                            return null;
                          }
                          final item = displaySales[groupIndex];
                          final pct = catalogTotal <= 0
                              ? 0.0
                              : (item.revenue / catalogTotal);
                          final revenueStr =
                              '₹${NumberFormat.compact().format(item.revenue)}';
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
                                text:
                                    '$revenueStr · ${(pct * 100).toStringAsFixed(1)}% of catalog\n',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                              TextSpan(
                                text: '${item.quantity} units sold',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  height: 1.35,
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
                          reservedSize: 26,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= displaySales.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '#${i + 1}',
                                style: TextStyle(
                                  color: i == 0
                                      ? AppColors.primary
                                      : AppColors.textLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) {
                            final label = value == 0
                                ? '0'
                                : '₹${NumberFormat.compact().format(value)}';
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                label,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 9,
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
                    barGroups: displaySales.asMap().entries.map((e) {
                      final i = e.key;
                      final color = _barPalette[i % _barPalette.length];
                      final isTop = i == 0;
                      return BarChartGroupData(
                        x: i,
                        barRods: [
                          BarChartRodData(
                            toY: e.value.revenue,
                            width: isTop ? 20 : 16,
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                color.withValues(alpha: isTop ? 0.65 : 0.5),
                                color,
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: AppColors.divider),
              ),
              const Text(
                'BREAKDOWN',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textLight,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              ...displaySales.asMap().entries.map((e) {
                final i = e.key;
                final item = e.value;
                final color = _barPalette[i % _barPalette.length];
                final pct = catalogTotal <= 0
                    ? 0.0
                    : (item.revenue / catalogTotal) * 100;
                final pctLabel = pct >= 10
                    ? '${pct.round()}%'
                    : '${pct.toStringAsFixed(1)}%';
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: i == displaySales.length - 1 ? 0 : 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${NumberFormat.compact().format(item.revenue)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            '$pctLabel · ${item.quantity} qty',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
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
                    const SizedBox(width: 8),
                    if (onTrailingTap != null)
                      TextButton(
                        onPressed: onTrailingTap,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          minimumSize: const Size(44, 40),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          trailingText!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        child: Text(
                          trailingText!,
                          style: TextStyle(
                            color: AppColors.primary.withValues(alpha: 0.85),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.show_chart_rounded,
                color: AppColors.textLight,
                size: 28,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No revenue trend yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Paid and recorded orders will build this 7-day chart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ],
        ),
      );
    }

    final maxValue = last
        .map((d) => d.amount)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final maxY = (maxValue <= 0 ? 1.0 : maxValue) * 1.22;
    final yInterval = maxY > 0 ? maxY / 4 : 1.0;
    final highlightIndex = _pickHighlightIndex(last);
    final weekTotal = last.fold<double>(0, (s, d) => s + d.amount);
    final weekOrders = last.fold<int>(0, (s, d) => s + d.count);
    final best = last[highlightIndex];
    final rangeStart = last.first.date;
    final rangeEnd = last.last.date;
    final rangeLabel =
        rangeStart.year == rangeEnd.year &&
            rangeStart.month == rangeEnd.month &&
            rangeStart.day == rangeEnd.day
        ? DateFormat('EEE, MMM d').format(rangeStart)
        : '${DateFormat('MMM d').format(rangeStart)} – ${DateFormat('MMM d').format(rangeEnd)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dailySales.length > 7)
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_view_week_rounded,
                  size: 16,
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Last 7 days on the chart · ${dailySales.length} days of history',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${NumberFormat.compact().format(weekTotal)} total',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rangeLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$weekOrders ${weekOrders == 1 ? 'order' : 'orders'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Best: ${DateFormat('EEE').format(best.date)} · ₹${NumberFormat.compact().format(best.amount)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: yInterval,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: AppColors.divider, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    barTouchData: BarTouchData(
                      enabled: true,
                      handleBuiltInTouches: true,
                      touchTooltipData: BarTouchTooltipData(
                        direction: TooltipDirection.top,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        tooltipBorderRadius: BorderRadius.circular(12),
                        tooltipMargin: 8,
                        maxContentWidth: 220,
                        fitInsideHorizontally: true,
                        fitInsideVertically: true,
                        getTooltipColor: (_) =>
                            AppColors.textPrimary.withValues(alpha: 0.94),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          if (groupIndex < 0 || groupIndex >= last.length) {
                            return null;
                          }
                          final d = last[groupIndex];
                          final val = rod.toY;
                          final label =
                              '₹${NumberFormat.compact().format(val)}';
                          final dayLine = DateFormat(
                            'EEEE, MMM d',
                          ).format(d.date);
                          final share = weekTotal <= 0
                              ? 0.0
                              : (val / weekTotal) * 100;
                          return BarTooltipItem(
                            '$dayLine\n',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              height: 1.25,
                            ),
                            children: [
                              TextSpan(
                                text: '$label · ${share.round()}% of week\n',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '${d.count} ${d.count == 1 ? 'order' : 'orders'}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                            ],
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
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: yInterval,
                          getTitlesWidget: (value, meta) {
                            final label = value == 0
                                ? '0'
                                : '₹${NumberFormat.compact().format(value)}';
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                label,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
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
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= last.length) {
                              return const SizedBox.shrink();
                            }
                            final isHighlight = i == highlightIndex;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                DateFormat(
                                  'EEE',
                                ).format(last[i].date).toUpperCase(),
                                style: TextStyle(
                                  color: isHighlight
                                      ? AppColors.primary
                                      : AppColors.textLight,
                                  fontSize: 10,
                                  fontWeight: isHighlight
                                      ? FontWeight.w900
                                      : FontWeight.w800,
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
                          showingTooltipIndicators: i == highlightIndex
                              ? const [0]
                              : const [],
                          barRods: [
                            BarChartRodData(
                              toY: last[i].amount,
                              width: i == highlightIndex ? 16 : 13,
                              borderRadius: BorderRadius.circular(10),
                              gradient: i == highlightIndex
                                  ? LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        AppColors.primary.withValues(
                                          alpha: 0.75,
                                        ),
                                        AppColors.primary,
                                      ],
                                    )
                                  : null,
                              color: i == highlightIndex
                                  ? null
                                  : AppColors.backgroundSecondary.withValues(
                                      alpha: 0.92,
                                    ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tap a bar for revenue, share of this period, and order count.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textLight.withValues(alpha: 0.95),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  int _pickHighlightIndex(List<DailySalesData> last) {
    final thuIndex = last.indexWhere(
      (d) => d.date.weekday == DateTime.thursday,
    );
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
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 40,
              color: AppColors.primary.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 14),
            const Text(
              'No orders yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create an order to see it show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/owner/orders/create');
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'New order',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primaryLighter.withValues(
                    alpha: 0.65,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
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
            onPressed: () {
              HapticFeedback.lightImpact();
              context.push('/owner/orders');
            },
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
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/owner/orders/${order.id}');
        },
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
