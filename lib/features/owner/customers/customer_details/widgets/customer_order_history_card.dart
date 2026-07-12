import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/detail_surfaces.dart';
import '../../../../../data/models/order.dart';
import '../../../orders/order_details/order_detail_formatting.dart';

/// Recent orders for this customer, newest first.
class CustomerOrderHistoryCard extends StatelessWidget {
  /// Every order for the customer, already sorted newest first.
  final List<Order> orders;

  /// How many rows to render before offering "View all".
  static const int visibleCount = 10;

  const CustomerOrderHistoryCard({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final visible = orders.take(visibleCount).toList();

    return DetailCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailSectionHeader(
            title: 'Order history',
            trailingWidget: orders.length > visibleCount
                ? GestureDetector(
                    onTap: () => context.push('/owner/orders'),
                    child: Text(
                      'View all (${orders.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 6),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'No orders yet',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            for (int i = 0; i < visible.length; i++) ...[
              _OrderRow(order: visible[i]),
              if (i != visible.length - 1)
                const Divider(height: 1, thickness: 1, color: AppColors.divider),
            ],
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final Order order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (order.status) {
      OrderStatus.pending => AppColors.warning,
      OrderStatus.delivered => AppColors.success,
      OrderStatus.cancelled => AppColors.error,
      _ => AppColors.info,
    };
    final dateLabel = DateFormat('MMM d').format(order.orderDate);

    return InkWell(
      onTap: () => context.push('/owner/orders/${order.id}'),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: statusColor,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${orderDetailDisplayId(order.id)} · $dateLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.status.name.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.4,
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
                  '₹${NumberFormat.decimalPattern().format(order.totalAmount)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                _PaymentMiniPill(status: order.paymentStatus),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentMiniPill extends StatelessWidget {
  final PaymentStatus? status;
  const _PaymentMiniPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status ?? PaymentStatus.unpaid;
    final (bg, fg, label) = switch (s) {
      PaymentStatus.paid => (
        AppColors.successLighter.withValues(alpha: 0.85),
        AppColors.success,
        'PAID',
      ),
      PaymentStatus.partial => (
        AppColors.warningLighter.withValues(alpha: 0.85),
        AppColors.warning,
        'PART',
      ),
      PaymentStatus.unpaid => (
        AppColors.errorLighter.withValues(alpha: 0.85),
        AppColors.error,
        'DUE',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
