import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/reports_provider.dart';
import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
        displacement: 64,
        strokeWidth: 2.5,
        onRefresh: () async {
          await _refreshOwnerDashboard(ref);
          if (context.mounted) {
            try {
              HapticFeedback.lightImpact();
            } catch (_) {}
          }
        },
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
                hasScrollBody: true,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: const _DashboardLoadingSkeleton(),
                ),
              )
            else if (isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(context),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (showOnboardingBanner) ...[
                      const _ResumeSetupBanner(),
                      const SizedBox(height: 20),
                    ],
                    const _SectionHeader(
                      eyebrow: 'Shortcuts',
                      title: 'Quick actions',
                      subtitle: 'Jump to the workflows you use most',
                    ),
                    const SizedBox(height: 16),
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
                    const SizedBox(height: 32),
                    const _SectionHeader(
                      eyebrow: 'This week',
                      title: 'Sales revenue',
                      subtitle: 'Daily revenue across the last 7 days',
                    ),
                    const SizedBox(height: 16),
                    _SalesTrendCard(dailySales: reports.dailySales),
                    const SizedBox(height: 32),
                    _SectionHeader(
                      eyebrow: 'Latest',
                      title: 'Recent orders',
                      subtitle: 'Tap a card to open details',
                      trailingLabel: 'View all',
                      onTrailingTap: () => context.push('/owner/orders'),
                    ),
                    const SizedBox(height: 16),
                    _RecentOrdersList(orders: orders),
                    const SizedBox(height: 32),
                    const _SectionHeader(
                      eyebrow: 'Catalog',
                      title: 'Product mix',
                      subtitle: 'Top sellers by revenue',
                    ),
                    const SizedBox(height: 16),
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
              _HeroTopRow(greeting: _greeting(), name: displayName),
              const SizedBox(height: 16),
              Text(
                dateStr,
                style: context.appTextStyles.sliverSubtitle.copyWith(
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
                style: context.appTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  height: 1.2,
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
                      style: context.appTextStyles.sectionHeader.copyWith(
                        color: Colors.white,
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
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'OWNER',
                      style: context.appTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        height: 1.0,
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
            try {
              HapticFeedback.lightImpact();
            } catch (_) {}
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Notifications coming soon',
                  style: context.appTextStyles.body.copyWith(
                    color: Colors.white,
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
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
          style: context.appTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: isLoading
                  ? Container(
                      height: 36,
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    )
                  : Text(
                      '₹${NumberFormat.decimalPattern('en_IN').format(totalRevenue.round())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.appTextStyles.sliverTitle.copyWith(
                        color: Colors.white,
                        fontSize: 36,
                        letterSpacing: -1.4,
                        height: 1.0,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
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
                      style: context.appTextStyles.sliverSubtitle.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.textLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    height: 1.0,
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
              style: context.appTextStyles.sliverTitle.copyWith(
                color: AppColors.textPrimary,
                fontSize: 20,
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
    return Semantics(
      header: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: context.appTextStyles.sliverTitle.copyWith(
                    fontSize: 17,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: context.appTextStyles.body.copyWith(
                      color: AppColors.textSecondary.withValues(alpha: 0.92),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingLabel != null) ...[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: '${trailingLabel!}, orders list',
              child: TextButton(
                onPressed: () {
                  try {
                    HapticFeedback.lightImpact();
                  } catch (_) {}
                  onTrailingTap?.call();
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  minimumSize: const Size(48, 44),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.primaryLighter.withValues(
                    alpha: 0.45,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      trailingLabel!,
                      style: context.appTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.15,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 15),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          const BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 6),
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
    return Semantics(
      button: true,
      label: 'Finish account setup',
      hint: 'Opens setup steps',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            try {
              HapticFeedback.mediumImpact();
            } catch (_) {}
            context.push('/onboarding');
          },
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(18, 17, 16, 17),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryGradientStart,
                        AppColors.primaryGradientEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.rocket_launch_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Finish account setup',
                        style: context.appTextStyles.sectionHeader.copyWith(
                          fontSize: 15,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'A few quick steps unlock the full workspace.',
                        style: context.appTextStyles.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.primary.withValues(alpha: 0.75),
                  size: 26,
                ),
              ],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
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
                  indent: 6,
                  endIndent: 6,
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
      waitDuration: const Duration(milliseconds: 500),
      child: Semantics(
        button: true,
        label: action.label,
        hint: 'Opens this section',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              try {
                HapticFeedback.lightImpact();
              } catch (_) {}
              context.push(action.path);
            },
            borderRadius: BorderRadius.circular(16),
            splashColor: action.color.withValues(alpha: 0.08),
            highlightColor: action.color.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                      style: context.appTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.05,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
    final t = context.appTextStyles;
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
    final chartMaxX = last.length <= 1 ? 1.0 : (last.length - 1).toDouble();
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

    final chartAxisMoneyStyle = t.caption.copyWith(
      color: AppColors.textLight,
      fontSize: 9,
      fontWeight: FontWeight.w900,
      height: 1.0,
    );
    final tooltipLeadStyle = t.sectionHeader.copyWith(
      color: Colors.white,
      fontSize: 12,
      height: 1.25,
    );
    final tooltipSpanStyle = t.caption.copyWith(
      color: Colors.white.withValues(alpha: 0.7),
      fontSize: 11,
      fontWeight: FontWeight.w800,
      height: 1.35,
    );

    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
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
                      style: t.sliverTitle.copyWith(
                        fontSize: 28,
                        letterSpacing: -0.85,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$weekOrders ${weekOrders == 1 ? 'order' : 'orders'} · $rangeLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: _BestDayChip(best: best),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: 'Chart hint',
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 16,
                  color: AppColors.textLight.withValues(alpha: 0.9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tap the chart for daily revenue, share of the week, and order count.',
                    style: t.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLight.withValues(alpha: 0.95),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: SizedBox(
              height: 188,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: chartMaxX,
                  minY: 0,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: AppColors.divider, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    handleBuiltInTouches: true,
                    touchTooltipData: LineTouchTooltipData(
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
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((spot) {
                          final i = spot.x.round();
                          if (i < 0 || i >= last.length) return null;
                          final d = last[i];
                          final val = d.amount;
                          final label =
                              '₹${NumberFormat.compact().format(val)}';
                          final dayLine = DateFormat(
                            'EEEE, MMM d',
                          ).format(d.date);
                          final share = weekTotal <= 0
                              ? 0.0
                              : (val / weekTotal) * 100;
                          return LineTooltipItem(
                            '$dayLine\n',
                            tooltipLeadStyle,
                            children: [
                              TextSpan(
                                text: '$label · ${share.round()}% of week\n',
                                style: tooltipSpanStyle,
                              ),
                              TextSpan(
                                text:
                                    '${d.count} ${d.count == 1 ? 'order' : 'orders'}',
                                style: tooltipSpanStyle,
                              ),
                            ],
                          );
                        }).toList();
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
                              style: chartAxisMoneyStyle,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final i = value.round();
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
                              style: t.caption.copyWith(
                                color: isHighlight
                                    ? AppColors.primary
                                    : AppColors.textLight,
                                fontSize: 10,
                                fontWeight: isHighlight
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (var i = 0; i < last.length; i++)
                          FlSpot(i.toDouble(), last[i].amount),
                      ],
                      isCurved: true,
                      curveSmoothness: 0.35,
                      preventCurveOverShooting: true,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      isStrokeJoinRound: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.85),
                          AppColors.primary,
                        ],
                      ),
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) {
                          final isHighlight = index == highlightIndex;
                          return FlDotCirclePainter(
                            radius: isHighlight ? 5.5 : 3.5,
                            color: isHighlight
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.5),
                            strokeWidth: isHighlight ? 2 : 1,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.20),
                            AppColors.primary.withValues(alpha: 0.02),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.auto_graph_rounded,
            size: 15,
            color: AppColors.primary.withValues(alpha: 0.95),
          ),
          const SizedBox(width: 6),
          Text(
            'Best ${DateFormat('EEE').format(best.date)} · ₹${NumberFormat.compact().format(best.amount)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.appTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.05,
              height: 1.0,
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
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: tone.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: tone, size: 28),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: context.appTextStyles.sectionHeader.copyWith(
            fontSize: 15,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: context.appTextStyles.body.copyWith(
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
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary.withValues(alpha: 0.88),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No orders yet',
              textAlign: TextAlign.center,
              style: context.appTextStyles.sectionHeader.copyWith(
                fontSize: 16,
                letterSpacing: -0.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create an order and it will appear in this list.',
              textAlign: TextAlign.center,
              style: context.appTextStyles.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.92),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  try {
                    HapticFeedback.lightImpact();
                  } catch (_) {}
                  context.push('/owner/orders/create');
                },
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  'New order',
                  style: context.appTextStyles.buttonLabel.copyWith(
                    fontSize: 14,
                    letterSpacing: 0.2,
                  ),
                ),
                style: FilledButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  backgroundColor: AppColors.primaryLighter.withValues(
                    alpha: 0.65,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < displayOrders.length; i++) ...[
          _SurfaceCard(
            padding: EdgeInsets.zero,
            child: _RecentOrderTile(order: displayOrders[i]),
          ),
          if (i != displayOrders.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  final Order order;
  const _RecentOrderTile({required this.order});

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  String _humanStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Out for delivery';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
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
    final statusColor = _getStatusColor(order.status);
    final statusChipBg = switch (order.status) {
      OrderStatus.pending => const Color(0xFF6D5EF6),
      _ => statusColor,
    };
    final amountLabel =
        '₹${NumberFormat.decimalPattern('en_IN').format(order.totalAmount)}';
    return Semantics(
      button: true,
      label:
          '${order.customerName}, $amountLabel, ${_humanStatus(order.status)}',
      hint: 'Opens order details',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            try {
              HapticFeedback.selectionClick();
            } catch (_) {}
            context.push('/owner/orders/${order.id}');
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 12, 15),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.5),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _initials(order.customerName),
                        style: context.appTextStyles.sectionHeader.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: statusChipBg,
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
                        style: context.appTextStyles.sectionHeader.copyWith(
                          fontSize: 15,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM d · hh:mm a').format(order.orderDate),
                        style: context.appTextStyles.caption.copyWith(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.95,
                          ),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      amountLabel,
                      style: context.appTextStyles.sectionHeader.copyWith(
                        fontSize: 15,
                        letterSpacing: -0.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusChipBg.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: statusChipBg.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _humanStatus(order.status),
                        style: context.appTextStyles.caption.copyWith(
                          color: statusChipBg,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textLight.withValues(alpha: 0.85),
                  size: 22,
                ),
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sortedSales.length > 5)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.45),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: AppColors.info.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Showing top 5 by revenue · ${sortedSales.length} products total',
                        style: context.appTextStyles.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.95,
                          ),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
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
                topRevenue: displaySales.isEmpty
                    ? 0
                    : displaySales.first.revenue,
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
    final pctLabel = pct >= 10
        ? '${pct.round()}%'
        : '${pct.toStringAsFixed(1)}%';
    final progress = topRevenue <= 0
        ? 0.0
        : (item.revenue / topRevenue).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              alignment: Alignment.center,
              child: Text(
                '$rank',
                style: context.appTextStyles.caption.copyWith(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.appTextStyles.sectionHeader.copyWith(
                  fontSize: 14,
                  height: 1.25,
                  letterSpacing: -0.15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '₹${NumberFormat.compact().format(item.revenue)}',
              style: context.appTextStyles.sectionHeader.copyWith(
                fontSize: 14,
                letterSpacing: -0.25,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: color.withValues(alpha: 0.08),
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$pctLabel · ${item.quantity} qty',
              style: context.appTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textLight,
                height: 1.2,
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

/// Layout-aware placeholders so the dashboard “shape” appears while data loads.
class _DashboardLoadingSkeleton extends StatelessWidget {
  const _DashboardLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading dashboard, please wait',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DeliveroSkeleton(width: 4, height: 44, borderRadius: 2),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DeliveroSkeleton(
                        width: 72,
                        height: 10,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      const DeliveroSkeleton(
                        width: double.infinity,
                        height: 22,
                        borderRadius: 8,
                      ),
                      const SizedBox(height: 8),
                      const DeliveroSkeleton(
                        width: double.infinity,
                        height: 14,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            DeliveroSkeleton(height: 92, borderRadius: 24),
            const SizedBox(height: 36),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DeliveroSkeleton(width: 4, height: 44, borderRadius: 2),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DeliveroSkeleton(
                        width: 64,
                        height: 10,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      const DeliveroSkeleton(
                        width: double.infinity,
                        height: 22,
                        borderRadius: 8,
                      ),
                      const SizedBox(height: 8),
                      DeliveroSkeleton(
                        width: MediaQuery.sizeOf(context).width * 0.55,
                        height: 14,
                        borderRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const DeliveroSkeleton(height: 220, borderRadius: 24),
            const SizedBox(height: 36),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DeliveroSkeleton(width: 4, height: 44, borderRadius: 2),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DeliveroSkeleton(
                        width: 56,
                        height: 10,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      const DeliveroSkeleton(
                        width: double.infinity,
                        height: 22,
                        borderRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const DeliveroSkeleton(height: 88, borderRadius: 24),
            const SizedBox(height: 10),
            const DeliveroSkeleton(height: 88, borderRadius: 24),
            const SizedBox(height: 10),
            const DeliveroSkeleton(height: 88, borderRadius: 24),
            const SizedBox(height: 36),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DeliveroSkeleton(width: 4, height: 44, borderRadius: 2),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DeliveroSkeleton(
                        width: 52,
                        height: 10,
                        borderRadius: 4,
                      ),
                      const SizedBox(height: 8),
                      const DeliveroSkeleton(
                        width: double.infinity,
                        height: 22,
                        borderRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const DeliveroSkeleton(height: 160, borderRadius: 24),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Loading your workspace…',
                textAlign: TextAlign.center,
                style: context.appTextStyles.body.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
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
              style: context.appTextStyles.caption.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
