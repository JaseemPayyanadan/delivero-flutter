import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';

class DeliveryDashboardScreen extends ConsumerWidget {
  const DeliveryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final allOrders = ref.watch(ordersProvider);

    // Filter orders for the current driver
    final myOrders = allOrders
        .where((o) => o.assignedDriver == user?.id)
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

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 140.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hello, ${user?.name ?? 'Driver'}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    'Your Dashboard',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              background: Container(color: AppColors.backgroundPrimary),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: 'OVERVIEW'),
                  const SizedBox(height: 16),
                  _buildOverviewGrid(
                    myOrders.length,
                    completedCount,
                    pendingCount,
                    todayOrders.length,
                  ),
                  const SizedBox(height: 32),
                  const _SectionHeader(title: 'TODAY\'S FINANCIALS'),
                  const SizedBox(height: 16),
                  _buildFinancialCard(todayCash, todayUpi, todayPending),
                  const SizedBox(height: 32),
                  const _SectionHeader(title: 'ACTIVITY SUMMARY'),
                  const SizedBox(height: 16),
                  _buildOrderSummary(myOrders),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewGrid(int total, int completed, int pending, int today) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatItem(
          'Total Orders',
          total.toString(),
          Icons.inventory_2_outlined,
          AppColors.info,
        ),
        _buildStatItem(
          'Completed',
          completed.toString(),
          Icons.task_alt_outlined,
          AppColors.success,
        ),
        _buildStatItem(
          'Pending',
          pending.toString(),
          Icons.timer_outlined,
          AppColors.warning,
        ),
        _buildStatItem(
          'Today\'s Task',
          today.toString(),
          Icons.today_outlined,
          AppColors.primary,
        ),
      ],
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
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
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Total Collected Today',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${(cash + upi).toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildFinancialItem(
                'Cash',
                '₹${cash.toStringAsFixed(0)}',
                Icons.payments_outlined,
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildFinancialItem(
                'UPI',
                '₹${upi.toStringAsFixed(0)}',
                Icons.qr_code_scanner_outlined,
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildFinancialItem(
                'Pending',
                '₹${pending.toStringAsFixed(0)}',
                Icons.hourglass_empty_outlined,
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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32),
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
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
            fontSize: 15,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: AppColors.textLight,
        letterSpacing: 1.2,
      ),
    );
  }
}
