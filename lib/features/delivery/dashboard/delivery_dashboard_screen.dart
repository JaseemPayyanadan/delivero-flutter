import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/order.dart';
import '../delivery_nav_provider.dart';

class DeliveryDashboardScreen extends ConsumerWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final allOrders = ref.watch(ordersProvider);
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final isLoading = !ordersLoaded && allOrders.isEmpty;

    // Filter orders for the current driver
    final driverId = user?.linkedEntityId ?? user?.id;
    final myOrders = allOrders
        .where((o) => o.assignedDriver == driverId)
        .toList();

    // Today's orders
    final today = DateTime.now();
    final todayOrders = myOrders.where((o) {
      return o.orderDate.year == today.year &&
          o.orderDate.month == today.month &&
          o.orderDate.day == today.day;
    }).toList();

    // Financials
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
    final now = DateTime.now();
    final dateLabel = DateFormat('EEE, d MMM').format(now);

    final upcomingToday = [...todayOrders]
      ..sort((a, b) {
        final p = _statusPriority(
          a.status,
        ).compareTo(_statusPriority(b.status));
        if (p != 0) return p;
        return b.totalAmount.compareTo(a.totalAmount);
      });

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: RefreshIndicator(
        onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverAppBar(
              expandedHeight: 268.0,
              floating: false,
              pinned: true,
              toolbarHeight: 0,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.backgroundPrimary,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              systemOverlayStyle: AppTheme.systemOverlayStyle.copyWith(
                statusBarColor: AppColors.infoLighter.withValues(alpha: 0.35),
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
                            AppColors.infoLighter.withValues(alpha: 0.35),
                            AppColors.backgroundPrimary,
                            AppColors.backgroundPrimary,
                          ],
                          stops: const [0.0, 0.65, 1.0],
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
                                  'Hello, ${user?.name ?? 'Driver'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.9,
                                    ),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
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
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Dashboard',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              _HeaderPill(text: dateLabel.toUpperCase()),
                            ],
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 86,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              children: [
                                _KpiCard(
                                  title: 'Today Tasks',
                                  value: isLoading
                                      ? '—'
                                      : todayOrders.length.toString(),
                                  icon: Icons.today_rounded,
                                  tone: _KpiTone.primary,
                                ),
                                const SizedBox(width: 12),
                                _KpiCard(
                                  title: 'Pending',
                                  value: isLoading
                                      ? '—'
                                      : todayPendingCount.toString(),
                                  icon: Icons.timer_rounded,
                                  tone: _KpiTone.warning,
                                ),
                                const SizedBox(width: 12),
                                _KpiCard(
                                  title: 'Delivered',
                                  value: isLoading
                                      ? '—'
                                      : todayDeliveredCount.toString(),
                                  icon: Icons.check_circle_rounded,
                                  tone: _KpiTone.success,
                                ),
                                const SizedBox(width: 12),
                                _KpiCard(
                                  title: 'Collected',
                                  value: isLoading
                                      ? '—'
                                      : '₹${NumberFormat.compact().format(todayTotal)}',
                                  icon: Icons.payments_rounded,
                                  tone: _KpiTone.neutral,
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
            ),
            if (isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (myOrders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 60,
                    ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
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
                ),
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
                            label: 'Assigned Orders',
                            icon: Icons.list_alt_rounded,
                            color: AppColors.primary,
                            onTap: () {
                              ref
                                  .read(deliveryNavIndexProvider.notifier)
                                  .setIndex(1);
                            },
                          ),
                          _QuickAction(
                            label: 'Settings',
                            icon: Icons.settings_rounded,
                            color: AppColors.info,
                            onTap: () {
                              ref
                                  .read(deliveryNavIndexProvider.notifier)
                                  .setIndex(2);
                            },
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
                      const SizedBox(height: 24),
                      _SectionTitle(
                        title: 'Today’s Deliveries',
                        subtitle: 'Focus on pending stops first',
                      ),
                      const SizedBox(height: 12),
                      _TodayOrdersCard(orders: upcomingToday),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: 'Today',
                        subtitle: 'Collections and outstanding amounts',
                      ),
                      const SizedBox(height: 14),
                      _buildFinancialCard(todayCash, todayUpi, todayPending),
                      const SizedBox(height: 20),
                      _SectionTitle(
                        title: 'All-Time Summary',
                        subtitle: 'Your overall delivery performance',
                      ),
                      const SizedBox(height: 12),
                      _buildPerformanceCard(
                        total: myOrders.length,
                        completed: completedCount,
                        pending: pendingCount,
                      ),
                      const SizedBox(height: 16),
                      _buildOrderSummary(myOrders),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard({
    required int total,
    required int completed,
    required int pending,
  }) {
    final completionRate = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(28),
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
        children: [
          Row(
            children: [
              _MiniStat(
                label: 'Total',
                value: total.toString(),
                color: AppColors.info,
              ),
              const SizedBox(width: 12),
              _MiniStat(
                label: 'Completed',
                value: completed.toString(),
                color: AppColors.success,
              ),
              const SizedBox(width: 12),
              _MiniStat(
                label: 'Pending',
                value: pending.toString(),
                color: AppColors.warning,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: completionRate.clamp(0.0, 1.0),
              minHeight: 10,
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
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCard(double cash, double upi, double pending) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryGradientStart,
            AppColors.primaryGradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative sparkle icon in corner
          Positioned(
            top: -8,
            right: -4,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white.withValues(alpha: 0.08),
              size: 80,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Collected Today',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '\u20b9${(cash + upi).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildFinancialItem(
                    'Cash',
                    '\u20b9${cash.toStringAsFixed(0)}',
                    Icons.payments_outlined,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white24,
                  ),
                  _buildFinancialItem(
                    'UPI',
                    '\u20b9${upi.toStringAsFixed(0)}',
                    Icons.qr_code_scanner_outlined,
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white24,
                  ),
                  _buildFinancialItem(
                    'Pending',
                    '\u20b9${pending.toStringAsFixed(0)}',
                    Icons.hourglass_empty_outlined,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummary(List<Order> orders) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            'Deliveries Scheduled',
            orders.length.toString(),
            AppColors.info,
            Icons.calendar_today_outlined,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border),
          ),
          _buildSummaryRow(
            'Pending for Today',
            orders
                .where((o) => o.status == OrderStatus.pending)
                .length
                .toString(),
            AppColors.warning,
            Icons.hourglass_top_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ),
      ],
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

class _QuickActionsRow extends StatelessWidget {
  final List<_QuickAction> actions;
  const _QuickActionsRow({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
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
          for (var i = 0; i < actions.length; i++) ...[
            Expanded(child: _QuickActionTile(action: actions[i])),
            if (i != actions.length - 1)
              Container(
                width: 1,
                height: 44,
                color: AppColors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 10),
              ),
          ],
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
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: action.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(action.icon, color: action.color, size: 18),
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
        accent = AppColors.textSecondary;
        tint = AppColors.backgroundSecondary;
        break;
    }

    return Container(
      width: 156,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 18),
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
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left accent bar
        Container(
          width: 3,
          height: 38,
          margin: const EdgeInsets.only(right: 12, top: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primary,
                AppColors.primaryGradientEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
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
                letterSpacing: 1.0,
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
      ),
    );
  }
}

class _TodayOrdersCard extends StatelessWidget {
  final List<Order> orders;
  const _TodayOrdersCard({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: const Text(
          'No deliveries assigned for today.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final visible = orders.take(6).toList();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
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
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            _TodayOrderTile(order: visible[i]),
            if (i != visible.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: Divider(height: 1, color: AppColors.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _TodayOrderTile extends StatelessWidget {
  final Order order;
  const _TodayOrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order.status.name.toUpperCase();
    final statusColor = _statusColor(order.status);
    final payLabel = order.paymentStatus?.name.toUpperCase() ?? 'UNKNOWN';
    final amount = '₹${NumberFormat.compact().format(order.totalAmount)}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    _Chip(text: status, color: statusColor),
                    const SizedBox(width: 8),
                    _Chip(text: payLabel, color: AppColors.textLight),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

Color _statusColor(OrderStatus status) {
  switch (status) {
    case OrderStatus.delivered:
      return AppColors.success;
    case OrderStatus.pending:
    case OrderStatus.confirmed:
    case OrderStatus.preparing:
    case OrderStatus.ready:
      return AppColors.warning;
    case OrderStatus.cancelled:
      return AppColors.error;
  }
}
