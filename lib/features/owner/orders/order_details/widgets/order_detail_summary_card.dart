import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../data/models/order.dart';
import '../order_detail_formatting.dart';
import 'order_detail_surfaces.dart';
import '../../../../../core/widgets/detail_surfaces.dart';

/// Hero card straddling the purple header: status + copy ID on top, then a
/// two-column split — order total / balance due on the left, date and order
/// type on the right.
class OrderDetailSummaryCard extends StatelessWidget {
  final Order order;
  final String orderIdDisplay;
  final NumberFormat money0;
  final PaymentStatus paymentStatus;
  final double balanceDue;

  const OrderDetailSummaryCard({
    super.key,
    required this.order,
    required this.orderIdDisplay,
    required this.money0,
    required this.paymentStatus,
    required this.balanceDue,
  });

  void _copyId(BuildContext context) {
    Clipboard.setData(ClipboardData(text: orderIdDisplay));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$orderIdDisplay copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLine = DateFormat('EEEE, d MMM yyyy').format(order.orderDate);
    final orderTypeLabel = switch (order.orderType) {
      OrderType.daily => 'Daily Order',
      OrderType.oneTime => 'One-time Order',
      OrderType.special => 'Special Order',
    };
    final showDue = paymentStatus != PaymentStatus.paid && balanceDue > 0.004;
    final dueColor = paymentStatus == PaymentStatus.unpaid
        ? AppColors.error
        : AppColors.warning;
    final captionMuted = context.appTextStyles.caption.copyWith(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.35,
    );
    final isDelivered = order.status == OrderStatus.delivered;

    return DetailCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OrderDetailStatusPill(
                label: orderDetailHumanize(order.status.name),
                bg: orderDetailStatusBg(order.status),
                fg: orderDetailStatusFg(order.status),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _copyId(context),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Order Total', style: captionMuted),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          money0.format(order.totalAmount),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                            letterSpacing: -1.1,
                            height: 1.05,
                          ),
                        ),
                      ),
                      if (showDue) ...[
                        const SizedBox(height: 6),
                        Text(
                          paymentStatus == PaymentStatus.partial
                              ? '${money0.format(balanceDue)} balance due'
                              : '${money0.format(balanceDue)} due',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: dueColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: AppColors.divider,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _IconInfoRow(
                        icon: Icons.calendar_today_rounded,
                        label: dateLine,
                      ),
                      const SizedBox(height: 12),
                      _IconInfoRow(
                        icon: Icons.autorenew_rounded,
                        label: orderTypeLabel,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isDelivered && order.deliveryTime != null) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  'Delivered · ${DateFormat('d MMM yyyy · HH:mm').format(order.deliveryTime!)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IconInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IconInfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
