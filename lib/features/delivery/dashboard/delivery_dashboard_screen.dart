import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../../app/providers.dart';
import '../../../core/utils/debounced_refresh.dart';
import '../../../core/services/connectivity_provider.dart';
import '../../../core/widgets/offline_banner.dart';
import '../../../core/widgets/dashboard_hero_banner_art.dart';
import '../../../core/orders/order_sort.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/order.dart';
import '../driver_order_scope.dart';
import '../delivery_nav_provider.dart';

// ---------------------------------------------------------------------------
// Public screen
// ---------------------------------------------------------------------------

class DeliveryDashboardScreen extends ConsumerStatefulWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  ConsumerState<DeliveryDashboardScreen> createState() =>
      _DeliveryDashboardScreenState();
}

class _DeliveryDashboardScreenState
    extends ConsumerState<DeliveryDashboardScreen> {
  final _refresh = DebouncedRefresh();

  Future<void> _onRefresh() {
    return _refresh.run(() => ref.read(ordersProvider.notifier).refresh());
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final allOrders = ref.watch(ordersProvider);
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final isLoading = !ordersLoaded && allOrders.isEmpty;

    final driverId = user?.linkedEntityId ?? user?.id;
    final drivers = ref.watch(driversProvider);
    final me = drivers.firstWhereOrNull((d) => d.id == driverId);
    final myRouteId = me?.currentRoute?.trim();

    final myOrders = driverScopedOrders(
      allOrders,
      driverId: driverId,
      routeId: myRouteId,
    );

    final today = DateTime.now();
    final todayOrders = myOrders.where((o) {
      return o.orderDate.year == today.year &&
          o.orderDate.month == today.month &&
          o.orderDate.day == today.day;
    }).toList();

    double todayCash = 0;
    double todayUpi = 0;
    double todayPending = 0;

    for (var order in todayOrders) {
      if (order.paymentStatus == PaymentStatus.paid) {
        if (order.paymentMethod == PaymentMethod.cash) {
          todayCash += order.totalAmount;
        } else {
          todayUpi += order.totalAmount;
        }
      } else if (order.paymentStatus == PaymentStatus.partial) {
        todayPending += (order.totalAmount - (order.amountPaid ?? 0));
        if (order.paymentMethod == PaymentMethod.cash) {
          todayCash += (order.amountPaid ?? 0);
        } else {
          todayUpi += (order.amountPaid ?? 0);
        }
      } else {
        todayPending += order.totalAmount;
      }
    }

    final completedCount = myOrders
        .where((o) => o.status == OrderStatus.delivered)
        .length;
    final activeCount = myOrders.where(isDriverActiveOrder).length;
    final todayDeliveredCount = todayOrders
        .where((o) => o.status == OrderStatus.delivered)
        .length;
    final todayActiveCount = todayOrders.where(isDriverActiveOrder).length;
    final todayTotal = todayCash + todayUpi;
    final dateLabel = DateFormat('EEEE, d MMMM').format(today);

    final upcomingToday = [...todayOrders]
      ..sort((a, b) {
        final p = _statusPriority(
          a.status,
        ).compareTo(_statusPriority(b.status));
        if (p != 0) return p;
        final byDate = compareOrdersByDate(a, b);
        if (byDate != 0) return byDate;
        return b.totalAmount.compareTo(a.totalAmount);
      });

    final bottomInset = MediaQuery.paddingOf(context).bottom + 100;
    final isOnline = ref.watch(connectivityProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: RefreshIndicator(
        color: AppColors.primary,
        displacement: 56,
        onRefresh: _onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            if (!isOnline) const SliverToBoxAdapter(child: OfflineBanner()),
            SliverToBoxAdapter(
              child: _DriverHero(
                displayName: user?.name ?? 'Driver',
                dateStr: dateLabel,
                isLoading: isLoading,
                todayTotal: todayTotal,
                todayPending: todayPending,
                todayTaskCount: todayOrders.length,
                todayActiveCount: todayActiveCount,
                todayDeliveredCount: todayDeliveredCount,
              ),
            ),
            if (isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  20,
                  kDashboardHeroKpiStripContentTopPadding,
                  20,
                  0,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _SectionHeader(
                      eyebrow: 'Shortcuts',
                      title: 'Quick actions',
                      subtitle: 'Jump to the workflows you use most',
                    ),
                    const SizedBox(height: 16),
                    _QuickActionsGrid(
                      actions: [
                        _QuickAction(
                          label: 'New order',
                          icon: Icons.add_shopping_cart_rounded,
                          color: AppColors.primary,
                          onTap: () => context.push('/delivery/new-order'),
                        ),
                        _QuickAction(
                          label: 'Assigned',
                          icon: Icons.list_alt_rounded,
                          color: AppColors.secondary,
                          onTap: () => ref
                              .read(deliveryNavIndexProvider.notifier)
                              .setIndex(1),
                        ),
                        _QuickAction(
                          label: 'Settings',
                          icon: Icons.settings_rounded,
                          color: AppColors.info,
                          onTap: () => ref
                              .read(deliveryNavIndexProvider.notifier)
                              .setIndex(2),
                        ),
                        _QuickAction(
                          label: 'Refresh',
                          icon: Icons.refresh_rounded,
                          color: AppColors.success,
                          onTap: () =>
                              ref.read(ordersProvider.notifier).refresh(),
                        ),
                      ],
                    ),
                    if (myOrders.isEmpty) ...[
                      const SizedBox(height: 32),
                      const _NoDeliveriesEmpty(),
                    ] else ...[
                      const SizedBox(height: 32),
                      _SectionHeader(
                        eyebrow: 'Today',
                        title: 'Deliveries',
                        subtitle: 'Focus on pending stops first',
                        trailingLabel: 'View all',
                        onTrailingTap: () => ref
                            .read(deliveryNavIndexProvider.notifier)
                            .setIndex(1),
                      ),
                      const SizedBox(height: 16),
                      _TodayDeliveriesCard(orders: upcomingToday),
                      const SizedBox(height: 32),
                      const _SectionHeader(
                        eyebrow: 'Today',
                        title: 'Collections',
                        subtitle: 'Cash, UPI and outstanding amounts',
                      ),
                      const SizedBox(height: 16),
                      _CollectionBreakdownCard(
                        cash: todayCash,
                        upi: todayUpi,
                        pending: todayPending,
                      ),
                      const SizedBox(height: 32),
                      const _SectionHeader(
                        eyebrow: 'Overview',
                        title: 'All-time performance',
                        subtitle: 'Your overall delivery summary',
                      ),
                      const SizedBox(height: 16),
                      _PerformanceCard(
                        total: myOrders.length,
                        completed: completedCount,
                        active: activeCount,
                      ),
                    ],
                    SizedBox(height: bottomInset),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

int _statusPriority(OrderStatus status) {
  switch (status) {
    case OrderStatus.pending:
      return 1;
    case OrderStatus.confirmed:
      return 2;
    case OrderStatus.preparing:
      return 3;
    case OrderStatus.ready:
      return 4;
    case OrderStatus.delivered:
      return 5;
    case OrderStatus.cancelled:
      return 6;
  }
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _DriverHero extends StatelessWidget {
  final String displayName;
  final String dateStr;
  final bool isLoading;
  final double todayTotal;
  final double todayPending;
  final int todayTaskCount;
  final int todayActiveCount;
  final int todayDeliveredCount;

  const _DriverHero({
    required this.displayName,
    required this.dateStr,
    required this.isLoading,
    required this.todayTotal,
    required this.todayPending,
    required this.todayTaskCount,
    required this.todayActiveCount,
    required this.todayDeliveredCount,
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
    final textWidth = MediaQuery.sizeOf(context).width * 0.56;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(child: DashboardHeroBackground()),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              topInset + 18,
              20,
              kDashboardHeroKpiStripBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: textWidth,
                  child: _HeroTopRow(greeting: _greeting(), name: displayName),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: textWidth,
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: textWidth,
                  child: _HeroCollected(
                    isLoading: isLoading,
                    todayTotal: todayTotal,
                    todayPending: todayPending,
                  ),
                ),
                const SizedBox(height: 22),
                _KpiStrip(
                  isLoading: isLoading,
                  todayTaskCount: todayTaskCount,
                  todayActiveCount: todayActiveCount,
                  todayDeliveredCount: todayDeliveredCount,
                ),
              ],
            ),
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
              Text(
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

class _HeroCollected extends StatelessWidget {
  final bool isLoading;
  final double todayTotal;
  final double todayPending;

  const _HeroCollected({
    required this.isLoading,
    required this.todayTotal,
    required this.todayPending,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COLLECTED TODAY',
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
            '₹${NumberFormat.decimalPattern('en_IN').format(todayTotal.round())}',
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
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_top_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Text(
                isLoading
                    ? '—'
                    : '₹${NumberFormat.compact().format(todayPending)} pending',
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

// ---------------------------------------------------------------------------
// KPI strip
// ---------------------------------------------------------------------------

class _KpiStrip extends StatelessWidget {
  final bool isLoading;
  final int todayTaskCount;
  final int todayActiveCount;
  final int todayDeliveredCount;

  const _KpiStrip({
    required this.isLoading,
    required this.todayTaskCount,
    required this.todayActiveCount,
    required this.todayDeliveredCount,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, kDashboardHeroKpiStripOffset),
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
                  iconTone: AppColors.primary,
                  title: 'Tasks',
                  isLoading: isLoading,
                  value: isLoading ? '—' : todayTaskCount.toString(),
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
                  icon: Icons.timer_rounded,
                  iconTone: AppColors.warning,
                  title: 'Active',
                  isLoading: isLoading,
                  value: isLoading ? '—' : todayActiveCount.toString(),
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
                  title: 'Delivered',
                  isLoading: isLoading,
                  value: isLoading ? '—' : todayDeliveredCount.toString(),
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
            Container(
              height: 22,
              width: 50,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(6),
              ),
            )
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
// Section header (mirrors owner dashboard for visual consistency)
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
              gradient: const LinearGradient(
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
              label: trailingLabel!,
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
// Surface card (matches owner dashboard)
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
// Quick actions
// ---------------------------------------------------------------------------

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _QuickActionsGrid extends StatelessWidget {
  final List<_QuickAction> actions;
  const _QuickActionsGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
              action.onTap();
            },
            borderRadius: BorderRadius.circular(16),
            splashColor: action.color.withValues(alpha: 0.08),
            highlightColor: action.color.withValues(alpha: 0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: action.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(action.icon, color: action.color, size: 18),
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.appTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
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
// Today's deliveries list
// ---------------------------------------------------------------------------

class _TodayDeliveriesCard extends StatelessWidget {
  final List<Order> orders;
  const _TodayDeliveriesCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    final visible = orders.take(5).toList();

    if (visible.isEmpty) {
      return _SurfaceCard(
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.success.withValues(alpha: 0.88),
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'All caught up for today',
              textAlign: TextAlign.center,
              style: context.appTextStyles.sectionHeader.copyWith(
                fontSize: 16,
                letterSpacing: -0.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No pending deliveries assigned for today.',
              textAlign: TextAlign.center,
              style: context.appTextStyles.body.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.92),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _SurfaceCard(
            padding: EdgeInsets.zero,
            child: _DeliveryTile(order: visible[i]),
          ),
          if (i != visible.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  final Order order;
  const _DeliveryTile({required this.order});

  Color _chipTextColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    if (hsl.lightness > 0.6) {
      return hsl.withLightness(0.35).toColor();
    }
    return base;
  }

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
      OrderStatus.pending => AppColors.warning,
      _ => statusColor,
    };
    final statusChipFg = _chipTextColor(statusChipBg);
    final amountLabel =
        '₹${NumberFormat.decimalPattern('en_IN').format(order.totalAmount)}';

    return Semantics(
      button: true,
      label: '${order.customerName}, $amountLabel, ${order.status.label}',
      hint: 'Opens order details',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            try {
              HapticFeedback.selectionClick();
            } catch (_) {}
            context.push('/delivery/orders/${order.id}');
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
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusChipBg.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        order.status.label,
                        style: context.appTextStyles.caption.copyWith(
                          color: statusChipFg,
                          fontWeight: FontWeight.w800,
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
// Collection breakdown card (replaces the bright primary-gradient card)
// ---------------------------------------------------------------------------

class _CollectionBreakdownCard extends StatelessWidget {
  final double cash;
  final double upi;
  final double pending;

  const _CollectionBreakdownCard({
    required this.cash,
    required this.upi,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: _BreakdownItem(
              icon: Icons.payments_rounded,
              tone: AppColors.success,
              label: 'Cash',
              amount: cash,
            ),
          ),
          const _BreakdownDivider(),
          Expanded(
            child: _BreakdownItem(
              icon: Icons.qr_code_rounded,
              tone: AppColors.info,
              label: 'UPI',
              amount: upi,
            ),
          ),
          const _BreakdownDivider(),
          Expanded(
            child: _BreakdownItem(
              icon: Icons.hourglass_top_rounded,
              tone: AppColors.warning,
              label: 'Pending',
              amount: pending,
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownDivider extends StatelessWidget {
  const _BreakdownDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _BreakdownItem extends StatelessWidget {
  final IconData icon;
  final Color tone;
  final String label;
  final double amount;

  const _BreakdownItem({
    required this.icon,
    required this.tone,
    required this.label,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    final amountLabel =
        '₹${NumberFormat.decimalPattern('en_IN').format(amount)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tone.withValues(alpha: 0.18)),
          ),
          child: Icon(icon, color: tone, size: 18),
        ),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amountLabel,
            style: context.appTextStyles.sectionHeader.copyWith(
              fontSize: 16,
              letterSpacing: -0.35,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: context.appTextStyles.caption.copyWith(
            color: AppColors.textLight,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Performance card
// ---------------------------------------------------------------------------

class _PerformanceCard extends StatelessWidget {
  final int total;
  final int completed;
  final int active;

  const _PerformanceCard({
    required this.total,
    required this.completed,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;

    return _SurfaceCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            total == 0 ? 'No deliveries yet' : '$completed of $total delivered',
            style: context.appTextStyles.sliverTitle.copyWith(
              fontSize: 16,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.border.withValues(alpha: 0.6),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.success,
              ),
            ),
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                _MetricChip(label: '$active active', color: AppColors.warning),
                const SizedBox(width: 8),
                _MetricChip(
                  label: '${(progress * 100).round()}% done',
                  color: AppColors.success,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final Color color;

  const _MetricChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: context.appTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _NoDeliveriesEmpty extends StatelessWidget {
  const _NoDeliveriesEmpty();

  @override
  Widget build(BuildContext context) {
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
              Icons.local_shipping_outlined,
              color: AppColors.primary.withValues(alpha: 0.88),
              size: 28,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No deliveries yet',
            textAlign: TextAlign.center,
            style: context.appTextStyles.sectionHeader.copyWith(
              fontSize: 16,
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an order for a customer on your route and it will show up here.',
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
                context.push('/delivery/new-order');
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
}
