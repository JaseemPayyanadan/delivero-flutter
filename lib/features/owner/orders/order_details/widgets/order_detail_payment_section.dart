import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/order.dart';
import '../order_detail_formatting.dart';
import 'order_detail_surfaces.dart';
import '../../../../../core/widgets/detail_surfaces.dart';

/// Read-only payment summary card. Payment is recorded via the
/// Mark-as-Delivered flow; after delivery, [onUpdatePayment] (when set)
/// exposes an "Update payment" link for collecting outstanding balance.
class OrderDetailPaymentCard extends StatelessWidget {
  final Order order;
  final NumberFormat money0;
  final PaymentStatus paymentStatus;
  final Color paymentColor;
  final double deliveryFee;
  final double effectivePaid;
  final double balanceDue;
  final VoidCallback? onUpdatePayment;

  const OrderDetailPaymentCard({
    super.key,
    required this.order,
    required this.money0,
    required this.paymentStatus,
    required this.paymentColor,
    required this.deliveryFee,
    required this.effectivePaid,
    required this.balanceDue,
    this.onUpdatePayment,
  });

  @override
  Widget build(BuildContext context) {
    final statusAmount = paymentStatus == PaymentStatus.paid
        ? order.totalAmount
        : balanceDue;
    final showMethod =
        paymentStatus != PaymentStatus.unpaid || order.paymentMethod != null;

    return DetailCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailSectionHeader(
            title: 'Payment',
            trailingWidget: OrderDetailPillBadge(
              label: orderDetailHumanize(paymentStatus.name).toUpperCase(),
              background: paymentColor == AppColors.error
                  ? AppColors.errorLighter.withValues(alpha: 0.68)
                  : paymentColor.withValues(alpha: 0.096),
              foreground: paymentColor,
              border: paymentColor.withValues(alpha: 0.22),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: paymentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  orderDetailHumanize(paymentStatus.name),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                money0.format(statusAmount),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          if (showMethod) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  _methodIcon(order.paymentMethod),
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  orderDetailHumanize(
                    (order.paymentMethod ?? PaymentMethod.cash).name,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const _DashedDivider(),
          const SizedBox(height: 14),
          OrderDetailSummaryRow(label: 'Subtotal', value: order.subtotal),
          if (order.discountAmount > 0.004) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Discount',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.success,
                    ),
                  ),
                ),
                Text(
                  '−${money0.format(order.discountAmount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          OrderDetailSummaryRow(label: 'Delivery Fee', value: deliveryFee),
          if (paymentStatus == PaymentStatus.partial) ...[
            const SizedBox(height: 10),
            OrderDetailSummaryRow(label: 'Paid Amount', value: effectivePaid),
            const SizedBox(height: 10),
            OrderDetailSummaryRow(label: 'Balance Due', value: balanceDue),
          ],
          if (order.paymentTime != null &&
              order.paymentStatus != PaymentStatus.unpaid) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Collected at',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  DateFormat('d MMM yyyy · HH:mm').format(order.paymentTime!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Text(
                  money0.format(order.totalAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          if (onUpdatePayment != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onUpdatePayment,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Update payment',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 5.0;
        const gap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + gap)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            count,
            (_) => const SizedBox(
              width: dashWidth,
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: AppColors.border),
              ),
            ),
          ),
        );
      },
    );
  }
}

IconData _methodIcon(PaymentMethod? method) => switch (method) {
  PaymentMethod.cash => Icons.payments_rounded,
  PaymentMethod.upi => Icons.qr_code_rounded,
  PaymentMethod.card => Icons.credit_card_rounded,
  PaymentMethod.online => Icons.language_rounded,
  null => Icons.payments_rounded,
};
