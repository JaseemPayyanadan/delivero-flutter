import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/reports_provider.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../core/widgets/delivero_skeleton.dart';
import '../../../data/models/order.dart';

// ---------------------------------------------------------------------------
// Public screen
// ---------------------------------------------------------------------------

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
    final bottomInset = MediaQuery.paddingOf(context).bottom + 100;

    final showOnboardingBanner =
        user != null && !user.hasFinishedOnboarding && !isLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: RefreshIndicator(
        color: AppColors.primary,
        displacement: 56,
        onRefresh: () => _refreshOwnerDashboard(ref),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _DashboardHero(
                displayName: displayName,
                dateStr: dateStr,
                isLoading: isLoading,
                totalRevenue: totalRevenue,
                todayOrdersCount: todayOrdersCount,
                customersCount: customers.length,
                fulfillmentRate: fulfillmentRate,
              ),
            ),
            if (isEmpty && isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _LoadingState(),
              )
            else if (isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (showOnboardingBanner) ...[
                      const SizedBox(height: 20),
                      const _ResumeSetupBanner(),
                    ],
                    const SizedBox(height: 24),
                    const _SectionHeader(
                      eyebrow: 'GO TO',
                      title: 'Quick actions',
                    ),
                    const SizedBox(height: 14),
                    _QuickActionsGrid(
                      actions: const [
                        _QuickAction(
                          label: 'New Order',
                          icon: Icons.shopping_cart_checkout_rounded,
                          color: AppColors.primary,
                          path: '/owner/orders/create',
                        ),
                        _QuickAction(
                          label: 'Customers',
                          icon: Icons.people_alt_rounded,
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
                          color: AppColors.warning,
                          path: '/owner/routes?tab=drivers',
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      eyebrow: 'THIS WEEK',
                      title: 'Sales revenue',
                      subtitle: 'Daily revenue across the last 7 days',
                    ),
                    const SizedBox(height: 14),
                    _SalesTrendCard(dailySales: reports.dailySales),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      eyebrow: 'LATEST',
                      title: 'Recent orders',
                      subtitle: 'Tap a row to open order details',
                      trailingLabel: 'View all',
                      onTrailingTap: () => context.push('/owner/orders'),
                    ),
                    const SizedBox(height: 14),
                    _RecentOrdersList(orders: orders),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      eyebrow: 'CATALOG',
                      title: 'Product mix',
                      subtitle: 'Top sellers by revenue',
                    ),
                    const SizedBox(height: 14),
                    _ProductSaleCard(productSales: reports.productSales),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DeliveroEmptyState(
            title: 'Ready to Build Your Dashboard?',
            subtitle:
                'Get started by adding customers, products, routes, and creating your first order',
            icon: Icons.dashboard_rounded,
            actionLabel: 'Add your first customer',
            onActionPressed: () {
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
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero header — gradient panel with greeting + revenue + KPI strip
// ---------------------------------------------------------------------------

class _DashboardHero extends StatelessWidget {
  final String displayName;
  final String dateStr;
  final bool isLoading;
  final double totalRevenue;
  final int todayOrdersCount;
  final int customersCount;
  final double fulfillmentRate;

  const _DashboardHero({
    required this.displayName,
    required this.dateStr,
    required this.isLoading,
    required this.totalRevenue,
    required this.todayOrdersCount,
    required this.customersCount,
    required this.fulfillmentRate,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryGradientStart,
            AppColors.primaryGradientEnd,
          ],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -50,
            child: _GlowBlob(
              size: 200,
              color: AppColors.primaryLight.withValues(alpha: 0.32),
            ),
          ),
          Positioned(
            bottom: -10,
            left: -40,
            child: _GlowBlob(
              size: 160,
              color: AppColors.info.withValues(alpha: 0.22),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroTopRow(
                greeting: _greeting(),
                name: displayName,
              ),
              const SizedBox(height: 22),
              const Text(
                'Dashboard',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.1,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                dateStr,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 22),
              _HeroRevenue(
                isLoading: isLoading,
                totalRevenue: totalRevenue,
                todayOrdersCount: todayOrdersCount,
              ),
              const SizedBox(height: 22),
              _KpiStrip(
                isLoading: isLoading,
                todayOrdersCount: todayOrdersCount,
                customersCount: customersCount,
                fulfillmentRate: fulfillmentRate,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroTopRow extends StatelessWidget {
  final String greeting;
  final String name;

  const _HeroTopRow({required this.greeting, required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
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
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Text(
                      'OWNER',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _HeroIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
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
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeroIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

class _HeroRevenue extends StatelessWidget {
  final bool isLoading;
  final double totalRevenue;
  final int todayOrdersCount;

  const _HeroRevenue({
    required this.isLoading,
    required this.totalRevenue,
    required this.todayOrdersCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TOTAL REVENUE',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        if (isLoading)
          Container(
            height: 36,
            width: 160,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
          )
        else
          Text(
            '₹${NumberFormat.decimalPattern('en_IN').format(totalRevenue.round())}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.4,
              height: 1.0,
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bolt_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Text(
                isLoading
                    ? '—'
                    : '$todayOrdersCount ${todayOrdersCount == 1 ? 'order' : 'orders'} today',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowBlob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI strip — overlapping the hero, glanceable secondary metrics
// ---------------------------------------------------------------------------

class _KpiStrip extends StatelessWidget {
  final bool isLoading;
  final int todayOrdersCount;
  final int customersCount;
  final double fulfillmentRate;

  const _KpiStrip({
    required this.isLoading,
    required this.todayOrdersCount,
    required this.customersCount,
    required this.fulfillmentRate,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 36),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGradientEnd.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _KpiPill(
                  icon: Icons.today_rounded,
                  iconTone: AppColors.info,
                  title: 'Orders Today',
                  isLoading: isLoading,
                  value: isLoading ? '—' : todayOrdersCount.toString(),
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.divider,
                indent: 6,
                endIndent: 6,
              ),
              Expanded(
                child: _KpiPill(
                  icon: Icons.people_alt_rounded,
                  iconTone: AppColors.warning,
                  title: 'Customers',
                  isLoading: isLoading,
                  value: isLoading ? '—' : customersCount.toString(),
                ),
              ),
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: AppColors.divider,
                indent: 6,
                endIndent: 6,
              ),
              Expanded(
                child: _KpiPill(
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
        ),
      ),
    );
  }
}

class _KpiPill extends StatelessWidget {
  final IconData icon;
  final Color iconTone;
  final String title;
  final String value;
  final bool isLoading;

  const _KpiPill({
    required this.icon,
    required this.iconTone,
    required this.title,
    required this.value,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconTone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconTone, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const DeliveroSkeleton(height: 22, width: 60)
          else
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                height: 1.0,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header — single consistent pattern for all sections
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final String? trailingLabel;
  final VoidCallback? onTrailingTap;

  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailingLabel,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailingLabel != null) ...[
          const SizedBox(width: 12),
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onTrailingTap?.call();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trailingLabel!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, size: 14),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Surface — single shared card style
// ---------------------------------------------------------------------------

class _SurfaceCard extends StatelessWidget {
  final EdgeInsetsGeometry padding;
  final Widget child;

  const _SurfaceCard({
    this.padding = const EdgeInsets.all(18),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
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
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Resume Setup banner — refined hairline tile (no clashing warm gradient)
// ---------------------------------------------------------------------------

class _ResumeSetupBanner extends StatelessWidget {
  const _ResumeSetupBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push('/onboarding');
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.primaryLighter.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Finish account setup',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Complete a few steps to unlock all features and insights.',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.primary.withValues(alpha: 0.85),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions
// ---------------------------------------------------------------------------

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

class _QuickActionsGrid extends StatelessWidget {
  final List<_QuickAction> actions;
  const _QuickActionsGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
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
                  indent: 8,
                  endIndent: 8,
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(action.path);
        },
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(action.icon, color: action.color, size: 20),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
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
    );
  }
}

// ---------------------------------------------------------------------------
// Sales trend
// ---------------------------------------------------------------------------

class _SalesTrendCard extends StatelessWidget {
  final List<DailySalesData> dailySales;
  const _SalesTrendCard({required this.dailySales});

  @override
  Widget build(BuildContext context) {
    final last = dailySales.length > 7
        ? dailySales.sublist(dailySales.length - 7)
        : dailySales;

    if (last.isEmpty) {
      return _SurfaceCard(
        padding: const EdgeInsets.all(22),
        child: _EmptyChartPlaceholder(
          icon: Icons.show_chart_rounded,
          tone: AppColors.primary,
          title: 'No revenue trend yet',
          subtitle: 'Paid and recorded orders will build this 7-day chart.',
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

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
                      '₹${NumberFormat.compact().format(weekTotal)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.8,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$weekOrders ${weekOrders == 1 ? 'order' : 'orders'} · $rangeLabel',
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
              _BestDayChip(best: best),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: AppColors.divider, strokeWidth: 1),
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
                      final label = '₹${NumberFormat.compact().format(val)}';
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
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              height: 1.35,
                            ),
                          ),
                          TextSpan(
                            text:
                                '${d.count} ${d.count == 1 ? 'order' : 'orders'}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
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
                            DateFormat('EEE')
                                .format(last[i].date)
                                .toUpperCase(),
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
                      showingTooltipIndicators:
                          i == highlightIndex ? const [0] : const [],
                      barRods: [
                        BarChartRodData(
                          toY: last[i].amount,
                          width: i == highlightIndex ? 16 : 13,
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: i == highlightIndex
                                ? [
                                    AppColors.primary.withValues(alpha: 0.7),
                                    AppColors.primary,
                                  ]
                                : [
                                    AppColors.primary.withValues(alpha: 0.10),
                                    AppColors.primary.withValues(alpha: 0.22),
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
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  int _pickHighlightIndex(List<DailySalesData> last) {
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

class _BestDayChip extends StatelessWidget {
  final DailySalesData best;
  const _BestDayChip({required this.best});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'Best ${DateFormat('EEE').format(best.date)} · ₹${NumberFormat.compact().format(best.amount)}',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChartPlaceholder extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;

  const _EmptyChartPlaceholder({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: tone, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary.withValues(alpha: 0.95),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent orders
// ---------------------------------------------------------------------------

class _RecentOrdersList extends StatelessWidget {
  final List<Order> orders;
  const _RecentOrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    final recentOrders = orders.toList()
      ..sort((a, b) => b.orderDate.compareTo(a.orderDate));
    final displayOrders = recentOrders.take(5).toList();

    if (displayOrders.isEmpty) {
      return _SurfaceCard(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary.withValues(alpha: 0.85),
                size: 26,
              ),
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
            const SizedBox(height: 6),
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
            const SizedBox(height: 18),
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < displayOrders.length; i++) ...[
            _RecentOrderTile(order: displayOrders[i]),
            if (i != displayOrders.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Divider(height: 1, color: AppColors.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final Order order;
  const _RecentOrderTile({required this.order});

  Color _statusColor(OrderStatus status) {
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

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(order.status);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/owner/orders/${order.id}');
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(order.customerName),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
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
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('MMM d, hh:mm a').format(order.orderDate),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
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
                    '₹${NumberFormat.decimalPattern('en_IN').format(order.totalAmount)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      order.status.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Product Mix
// ---------------------------------------------------------------------------

class _ProductSaleCard extends StatelessWidget {
  final Map<String, ProductSalesData> productSales;
  const _ProductSaleCard({required this.productSales});

  static const List<Color> _palette = [
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
      return _SurfaceCard(
        padding: const EdgeInsets.all(22),
        child: _EmptyChartPlaceholder(
          icon: Icons.stacked_bar_chart_rounded,
          tone: AppColors.textLight,
          title: 'No product mix yet',
          subtitle:
              'When orders include line items, revenue share by product appears here.',
        ),
      );
    }

    final catalogTotal = sortedSales.fold<double>(
      0,
      (sum, e) => sum + e.revenue,
    );

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sortedSales.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.textLight.withValues(alpha: 0.95),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Top 5 by revenue · ${sortedSales.length} products in catalog',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textLight,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (var i = 0; i < displaySales.length; i++)
            Padding(
              padding: EdgeInsets.only(
                bottom: i == displaySales.length - 1 ? 0 : 16,
              ),
              child: _ProductMixRow(
                rank: i + 1,
                color: _palette[i % _palette.length],
                item: displaySales[i],
                catalogTotal: catalogTotal,
                topRevenue:
                    displaySales.isEmpty ? 0 : displaySales.first.revenue,
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductMixRow extends StatelessWidget {
  final int rank;
  final Color color;
  final ProductSalesData item;
  final double catalogTotal;
  final double topRevenue;

  const _ProductMixRow({
    required this.rank,
    required this.color,
    required this.item,
    required this.catalogTotal,
    required this.topRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final pct = catalogTotal <= 0 ? 0.0 : (item.revenue / catalogTotal) * 100;
    final pctLabel =
        pct >= 10 ? '${pct.round()}%' : '${pct.toStringAsFixed(1)}%';
    final progress =
        topRevenue <= 0 ? 0.0 : (item.revenue / topRevenue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  height: 1.25,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '₹${NumberFormat.compact().format(item.revenue)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: color.withValues(alpha: 0.10),
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 10),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Loading + empty-state helpers
// ---------------------------------------------------------------------------

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
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
                color: AppColors.textSecondary.withValues(alpha: 0.95),
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
