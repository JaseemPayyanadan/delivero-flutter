import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/reports_provider.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/delivero_button.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../core/widgets/delivero_skeleton.dart';
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
    final shortDateStr = DateFormat('EEE, d MMM').format(now).toUpperCase();
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
            SliverToBoxAdapter(
              child: _OwnerDashboardTop(
                displayName: displayName,
                dateStr: dateStr,
                shortDateStr: shortDateStr,
                isEmpty: isEmpty,
                isLoading: isLoading,
                totalRevenue: totalRevenue,
                todayOrdersCount: todayOrdersCount,
                customersCount: customers.length,
                fulfillmentRate: fulfillmentRate,
              ),
            ),
            if (user != null && !user.hasFinishedOnboarding && !isLoading)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                sliver: SliverToBoxAdapter(child: _ResumeSetupBanner()),
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
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 12),
                    _DashboardSection(
                      title: 'Sales Revenue',
                      trailingText: 'This Week',
                      child: _SalesTrendBars(dailySales: reports.dailySales),
                    ),
                    const SizedBox(height: 22),
                    _DashboardSection(
                      title: 'Recent Orders',
                      subtitle: 'Latest transactions across all accounts',
                      trailingText: 'View all',
                      onTrailingTap: () => context.push('/owner/orders'),
                      child: _RecentOrdersList(orders: orders),
                    ),
                    const SizedBox(height: 22),
                    _DashboardSection(
                      title: 'Product Mix',
                      subtitle: 'Revenue distribution across catalog',
                      child: _ProductSaleChart(
                        productSales: reports.productSales,
                      ),
                    ),
                    SizedBox(height: bottomInset),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DeliveroEmptyState(
          title: 'Ready to Build Your Dashboard?',
          subtitle:
              'Get started by adding customers, products, routes, and creating your first order',
          icon: Icons.dashboard_rounded,
          actionLabel: 'Add your first customer',
          onActionPressed: () {
            HapticFeedback.lightImpact();
            context.push('/owner/customers');
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _EmptyStateFeature(
                icon: Icons.people_alt_rounded,
                label: 'Customers',
                onTap: () => context.push('/owner/customers'),
              ),
              _EmptyStateFeature(
                icon: Icons.inventory_2_rounded,
                label: 'Products',
                onTap: () => context.push('/owner/food-items'),
              ),
              _EmptyStateFeature(
                icon: Icons.alt_route_rounded,
                label: 'Routes',
                onTap: () => context.push('/owner/routes'),
              ),
              _EmptyStateFeature(
                icon: Icons.receipt_long_rounded,
                label: 'Orders',
                onTap: () => context.push('/owner/orders'),
              ),
            ],
          ),
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
      ],
    );
  }
}

class _ResumeSetupBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/onboarding');
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppColors.primary,
              Color(0xFFFF8C33), // Lighter shade of primary
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.rocket_launch_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resume Account Setup',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Complete the setup guide to unlock all features and insights.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerDashboardTop extends StatelessWidget {
  final String displayName;
  final String dateStr;
  final String shortDateStr;
  final bool isEmpty;
  final bool isLoading;
  final double totalRevenue;
  final int todayOrdersCount;
  final int customersCount;
  final double fulfillmentRate;

  const _OwnerDashboardTop({
    required this.displayName,
    required this.dateStr,
    required this.shortDateStr,
    required this.isEmpty,
    required this.isLoading,
    required this.totalRevenue,
    required this.todayOrdersCount,
    required this.customersCount,
    required this.fulfillmentRate,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.85,
                          ),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Text(
                              'Owner',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _CircleIconButton(
                  icon: Icons.notifications_none_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Notifications coming soon',
                          style: TextStyle(fontWeight: FontWeight.w700),
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
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.9,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                _DatePill(text: shortDateStr),
              ],
            ),
            const SizedBox(height: 16),
            if (!isEmpty || isLoading) ...[
              Row(
                children: [
                  Expanded(
                    child: _DashboardKpiCard(
                      icon: Icons.currency_rupee_rounded,
                      iconTone: AppColors.primary,
                      title: 'Revenue',
                      isLoading: isLoading,
                      value: isLoading
                          ? '—'
                          : '₹${NumberFormat.compact().format(totalRevenue)}',
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _DashboardKpiCard(
                      icon: Icons.today_rounded,
                      iconTone: AppColors.info,
                      title: 'Orders Today',
                      isLoading: isLoading,
                      value: isLoading ? '—' : todayOrdersCount.toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DashboardKpiCard(
                      icon: Icons.people_alt_rounded,
                      iconTone: AppColors.warning,
                      title: 'Customers',
                      isLoading: isLoading,
                      value: isLoading ? '—' : customersCount.toString(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _DashboardKpiCard(
                      icon: Icons.check_circle_rounded,
                      iconTone: AppColors.success,
                      title: 'Fulfillment',
                      isLoading: isLoading,
                      value: isLoading
                          ? '—'
                          : '${(fulfillmentRate * 100).round()}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _QuickActionsRow(
                actions: const [
                  _QuickAction(
                    label: 'New Order',
                    icon: Icons.shopping_cart_checkout_rounded,
                    color: AppColors.primary,
                    path: '/owner/orders/create',
                  ),
                  _QuickAction(
                    label: 'Customers',
                    icon: Icons.receipt_long_rounded,
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
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 12,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 22),
        ),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  final String text;
  const _DatePill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _DashboardKpiCard extends StatelessWidget {
  final IconData icon;
  final Color iconTone;
  final String title;
  final String value;
  final bool isLoading;

  const _DashboardKpiCard({
    required this.icon,
    required this.iconTone,
    required this.title,
    required this.value,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left-border accent stripe
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [iconTone, iconTone.withValues(alpha: 0.5)],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: iconTone.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: iconTone, size: 20),
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
                      if (isLoading)
                        const DeliveroSkeleton(height: 24, width: 80)
                      else
                        Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color tone;

  const _MetricPill({
    required this.icon,
    required this.text,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tone),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tone,
                height: 1.1,
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowDeep,
            blurRadius: 22,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              Expanded(child: _QuickActionTile(action: actions[i])),
              if (i != actions.length - 1)
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: AppColors.divider,
                ),
            ],
          ],
        ),
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
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(action.icon, color: action.color, size: 20),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      height: 1.1,
                    ),
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
                            TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              height: 1.2,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    '$revenueStr · ${(pct * 100).toStringAsFixed(1)}% of catalog\n',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                              TextSpan(
                                text: '${item.quantity} units sold',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary
                                      .withValues(alpha: 0.7),
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
  final VoidCallback? onTap;

  const _EmptyStateFeature({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
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
        ),
      ),
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent bar
            Container(
              width: 3,
              height: 42,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primary, AppColors.primaryGradientEnd],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
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
                                color: AppColors.primary.withValues(
                                  alpha: 0.85,
                                ),
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
          ],
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
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowDeep,
              blurRadius: 22,
              offset: Offset(0, 14),
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
                color: AppColors.primaryLighter.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.show_chart_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Create an order to start tracking weekly revenue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        height: 1.2,
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
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowDeep,
                blurRadius: 24,
                offset: Offset(0, 16),
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
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLighter.withValues(
                                  alpha: 0.7,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.trending_up_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '₹${NumberFormat.compact().format(weekTotal)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total revenue · $rangeLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                      _MetricPill(
                        icon: Icons.receipt_long_rounded,
                        text:
                            '$weekOrders ${weekOrders == 1 ? 'order' : 'orders'}',
                        tone: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      _MetricPill(
                        icon: Icons.star_rounded,
                        text:
                            'Best ${DateFormat('EEE').format(best.date)} · ₹${NumberFormat.compact().format(best.amount)}',
                        tone: AppColors.primary,
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
                            TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              height: 1.25,
                            ),
                            children: [
                              TextSpan(
                                text: '$label · ${share.round()}% of week\n',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary
                                      .withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  height: 1.35,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '${d.count} ${d.count == 1 ? 'order' : 'orders'}',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary
                                      .withValues(alpha: 0.7),
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
                                  : LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        AppColors.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                        AppColors.primary.withValues(
                                          alpha: 0.18,
                                        ),
                                      ],
                                    ),
                              color: null,
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

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(order.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            context.push('/owner/orders/${order.id}');
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Status-tinted leading icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Icon(
                    Icons.receipt_outlined,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat('MMM d, hh:mm a').format(order.orderDate),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${NumberFormat.decimalPattern().format(order.totalAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          order.status.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 14,
                          color: AppColors.textLight,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
