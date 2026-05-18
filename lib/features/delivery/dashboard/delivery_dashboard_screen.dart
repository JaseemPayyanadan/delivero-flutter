import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../delivery_nav_provider.dart';

// ---------------------------------------------------------------------------
// Public screen
// ---------------------------------------------------------------------------

class DeliveryDashboardScreen extends ConsumerWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final allOrders = ref.watch(ordersProvider);
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final isLoading = !ordersLoaded && allOrders.isEmpty;

    final driverId = user?.linkedEntityId ?? user?.id;
    final drivers = ref.watch(driversProvider);
    final me = drivers.firstWhereOrNull((d) => d.id == driverId);
    final myRouteId = me?.currentRoute?.trim();

    final myOrders = allOrders.where((o) {
      if (driverId == null) return false;
      if (o.assignedDriver == driverId) return true;
      if (myRouteId == null || myRouteId.isEmpty) return false;
      return o.assignedRoute == myRouteId;
    }).toList();

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
    final pendingCount = myOrders
        .where((o) => o.status == OrderStatus.pending)
        .length;
    final todayDeliveredCount = todayOrders
        .where((o) => o.status == OrderStatus.delivered)
        .length;
    final todayPendingCount = todayOrders
        .where((o) => o.status == OrderStatus.pending)
        .length;
    final todayTotal = todayCash + todayUpi;
    final dateLabel = DateFormat('EEEE, d MMMM').format(today);

    final upcomingToday = [...todayOrders]
      ..sort((a, b) {
        final p = _statusPriority(
          a.status,
        ).compareTo(_statusPriority(b.status));
        if (p != 0) return p;
        return b.totalAmount.compareTo(a.totalAmount);
      });

    final bottomInset = MediaQuery.paddingOf(context).bottom + 100;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: RefreshIndicator(
        color: AppColors.primary,
        displacement: 56,
        onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _DriverHero(
                displayName: user?.name ?? 'Driver',
                dateStr: dateLabel,
                isLoading: isLoading,
                todayTotal: todayTotal,
                todayPending: todayPending,
                todayTaskCount: todayOrders.length,
                todayPendingCount: todayPendingCount,
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
            else if (myOrders.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _NoDeliveriesEmpty(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 24),
                    const _SectionHeader(
                      eyebrow: 'GO TO',
                      title: 'Quick actions',
                    ),
                    const SizedBox(height: 14),
                    _QuickActionsGrid(
                      actions: [
                        _QuickAction(
                          label: 'Assigned',
                          icon: Icons.list_alt_rounded,
                          color: AppColors.primary,
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
                    const SizedBox(height: 28),
                    const _SectionHeader(
                      eyebrow: 'TODAY',
                      title: 'Deliveries',
                      subtitle: 'Focus on pending stops first',
                    ),
                    const SizedBox(height: 14),
                    _TodayDeliveriesCard(orders: upcomingToday),
                    const SizedBox(height: 28),
                    const _SectionHeader(
                      eyebrow: 'TODAY',
                      title: 'Collections',
                      subtitle: 'Cash, UPI and outstanding amounts',
                    ),
                    const SizedBox(height: 14),
                    _CollectionBreakdownCard(
                      cash: todayCash,
                      upi: todayUpi,
                      pending: todayPending,
                    ),
                    const SizedBox(height: 28),
                    const _SectionHeader(
                      eyebrow: 'OVERVIEW',
                      title: 'All-time performance',
                      subtitle: 'Your overall delivery summary',
                    ),
                    const SizedBox(height: 14),
                    _PerformanceCard(
                      total: myOrders.length,
                      completed: completedCount,
                      pending: pendingCount,
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
  final int todayPendingCount;
  final int todayDeliveredCount;

  const _DriverHero({
    required this.displayName,
    required this.dateStr,
    required this.isLoading,
    required this.todayTotal,
    required this.todayPending,
    required this.todayTaskCount,
    required this.todayPendingCount,
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
              _HeroCollected(
                isLoading: isLoading,
                todayTotal: todayTotal,
                todayPending: todayPending,
              ),
              const SizedBox(height: 22),
              _KpiStrip(
                isLoading: isLoading,
                todayTaskCount: todayTaskCount,
                todayPendingCount: todayPendingCount,
                todayDeliveredCount: todayDeliveredCount,
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
                      'DRIVER',
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
// KPI strip
// ---------------------------------------------------------------------------

class _KpiStrip extends StatelessWidget {
  final bool isLoading;
  final int todayTaskCount;
  final int todayPendingCount;
  final int todayDeliveredCount;

  const _KpiStrip({
    required this.isLoading,
    required this.todayTaskCount,
    required this.todayPendingCount,
    required this.todayDeliveredCount,
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
                  title: 'Pending',
                  isLoading: isLoading,
                  value: isLoading ? '—' : todayPendingCount.toString(),
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

  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
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
          try {
            HapticFeedback.lightImpact();
          } catch (_) {}
          action.onTap();
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
// Today's deliveries list
// ---------------------------------------------------------------------------

class _TodayDeliveriesCard extends StatelessWidget {
  final List<Order> orders;
  const _TodayDeliveriesCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'No deliveries assigned for today.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final visible = orders.take(6).toList();
    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            _DeliveryTile(order: visible[i]),
            if (i != visible.length - 1)
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

class _DeliveryTile extends StatelessWidget {
  final Order order;
  const _DeliveryTile({required this.order});

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
      OrderStatus.pending => AppColors.warning,
      _ => statusColor,
    };
    final amount = '₹${NumberFormat.compact().format(order.totalAmount)}';
    final payLabel = order.paymentStatus?.name.toUpperCase() ?? 'UNKNOWN';

    return Padding(
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
                    color: statusChipBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
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
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _StatusChip(
                      text: _humanStatus(order.status),
                      color: statusChipBg,
                      solid: true,
                    ),
                    const SizedBox(width: 6),
                    _StatusChip(
                      text: payLabel,
                      color: AppColors.textSecondary,
                      solid: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final bool solid;

  const _StatusChip({
    required this.text,
    required this.color,
    this.solid = false,
  });

  Color _chipTextColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    if (hsl.lightness > 0.6) {
      return hsl.withLightness(0.35).toColor();
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final fg = _chipTextColor(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: solid ? 0.32 : 0.096),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.1,
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: tone, size: 18),
        ),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '₹${NumberFormat.compact().format(amount)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
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
  final int pending;

  const _PerformanceCard({
    required this.total,
    required this.completed,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    final completionRate = total == 0 ? 0.0 : completed / total;
    return _SurfaceCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Total',
                  value: total.toString(),
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Completed',
                  value: completed.toString(),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniStat(
                  label: 'Pending',
                  value: pending.toString(),
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completionRate.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.backgroundSecondary,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Completion rate',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(completionRate * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'No deliveries yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Orders assigned to you will appear here. Check back once your manager has created a delivery.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.85),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tips_and_updates_outlined,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Pull down to refresh',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
