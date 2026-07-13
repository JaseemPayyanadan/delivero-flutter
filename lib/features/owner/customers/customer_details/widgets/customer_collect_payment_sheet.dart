import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/order.dart';
import '../../../orders/order_details/order_detail_formatting.dart';
import '../../../orders/order_details/widgets/order_detail_update_payment_sheet.dart';

/// Amount still owed on [order].
double orderBalanceDue(Order order) =>
    (order.totalAmount - (order.amountPaid ?? 0)).clamp(0.0, double.infinity);

/// Orders this customer still owes money on, newest first.
List<Order> unsettledOrders(List<Order> customerOrders) => customerOrders
    .where(
      (o) =>
          o.status != OrderStatus.cancelled &&
          o.paymentStatus != PaymentStatus.paid &&
          orderBalanceDue(o) > 0.004,
    )
    .toList();

/// Lists the customer's unpaid orders so the owner can pick which one to
/// record a payment against. Each row opens the order's update-payment sheet.
Future<void> showCustomerCollectPaymentSheet({
  required BuildContext context,
  required WidgetRef ref,
  required List<Order> customerOrders,
}) async {
  final money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );
  final due = unsettledOrders(customerOrders);
  final total = due.fold(0.0, (sum, o) => sum + orderBalanceDue(o));

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Collect payment',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              due.isEmpty
                  ? 'Nothing outstanding.'
                  : '${money.format(total)} across ${due.length} ${due.length == 1 ? 'order' : 'orders'}. Pick one to record a payment.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: due.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (_, index) {
                  final order = due[index];
                  return _DueOrderRow(
                    order: order,
                    money: money,
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showOrderDetailUpdatePaymentSheet(
                        context: context,
                        ref: ref,
                        order: order,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DueOrderRow extends StatelessWidget {
  final Order order;
  final NumberFormat money;
  final VoidCallback onTap;

  const _DueOrderRow({
    required this.order,
    required this.money,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPartial = order.paymentStatus == PaymentStatus.partial;
    final accent = isPartial ? AppColors.warning : AppColors.error;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: accent,
                size: 19,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    orderDetailDisplayId(order.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('d MMM').format(order.orderDate)} · ${isPartial ? 'Partly paid' : 'Unpaid'}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              money.format(orderBalanceDue(order)),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 12,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }
}
