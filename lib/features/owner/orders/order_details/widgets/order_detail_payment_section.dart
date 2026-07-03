import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/order.dart';
import '../order_detail_formatting.dart';
import 'order_detail_surfaces.dart';

class OrderDetailPaymentSection extends StatelessWidget {
  final Order order;
  final NumberFormat money0;
  final PaymentStatus paymentStatus;
  final Color paymentColor;
  final double deliveryFee;
  final double effectivePaid;
  final double balanceDue;
  final PaymentStatus draftPaymentStatus;
  final PaymentMethod draftPaymentMethod;
  final TextEditingController partialAmountController;
  final double? draftAmountPaid;
  final ValueChanged<PaymentStatus> onDraftPaymentStatusChanged;
  final ValueChanged<PaymentMethod> onDraftPaymentMethodChanged;
  final ValueChanged<String> onPartialAmountChanged;
  final VoidCallback onResetPaymentDrafts;
  final WidgetRef ref;

  const OrderDetailPaymentSection({
    super.key,
    required this.order,
    required this.money0,
    required this.paymentStatus,
    required this.paymentColor,
    required this.deliveryFee,
    required this.effectivePaid,
    required this.balanceDue,
    required this.draftPaymentStatus,
    required this.draftPaymentMethod,
    required this.partialAmountController,
    required this.draftAmountPaid,
    required this.onDraftPaymentStatusChanged,
    required this.onDraftPaymentMethodChanged,
    required this.onPartialAmountChanged,
    required this.onResetPaymentDrafts,
    required this.ref,
  });

  void _onApply(BuildContext context) {
    final nextStatus = draftPaymentStatus;
    final nextMethod = draftPaymentMethod;
    double? amountPaid;

    if (nextStatus == PaymentStatus.unpaid) {
      amountPaid = null;
    } else if (nextStatus == PaymentStatus.paid) {
      amountPaid = order.totalAmount;
    } else {
      final parsed =
          (draftAmountPaid ??
              double.tryParse(
                partialAmountController.text.trim().replaceAll(',', ''),
              )) ??
          0.0;
      final clamped = parsed.clamp(0.0, order.totalAmount);
      if (clamped <= 0 || clamped >= order.totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter an amount between ${money0.format(1)} and ${money0.format(order.totalAmount - 1)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.warning,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
      amountPaid = clamped;
    }

    final next = order.copyWith(
      paymentStatus: nextStatus,
      paymentMethod: nextMethod,
      amountPaid: amountPaid,
      paymentTime: nextStatus == PaymentStatus.unpaid ? null : DateTime.now(),
      updatedAt: DateTime.now(),
    );
    ref.read(ordersProvider.notifier).updateOrder(next);
    ref
        .read(lastTouchedOrderProvider.notifier)
        .set(id: next.id, wasCreated: false);
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Payment status updated',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  double? _normalizedAmountForStatus(
    PaymentStatus status, {
    required double? amount,
  }) {
    return switch (status) {
      PaymentStatus.unpaid => null,
      PaymentStatus.paid => order.totalAmount,
      PaymentStatus.partial => amount,
    };
  }

  double? _parsedDraftAmount() {
    final raw = partialAmountController.text.trim().replaceAll(',', '');
    if (raw.isEmpty) return draftAmountPaid;
    return double.tryParse(raw) ?? draftAmountPaid;
  }

  bool _amountEquals(double? a, double? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return (a - b).abs() < 0.001;
  }

  @override
  Widget build(BuildContext context) {
    final originalStatus = order.paymentStatus ?? PaymentStatus.unpaid;
    final originalMethod = order.paymentMethod ?? PaymentMethod.cash;
    final originalAmount = _normalizedAmountForStatus(
      originalStatus,
      amount: order.amountPaid,
    );
    final draftNormalizedAmount = _normalizedAmountForStatus(
      draftPaymentStatus,
      amount: _parsedDraftAmount(),
    );
    final hasPaymentChanges =
        draftPaymentStatus != originalStatus ||
        draftPaymentMethod != originalMethod ||
        !_amountEquals(draftNormalizedAmount, originalAmount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OrderDetailSectionHeader(
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
        const SizedBox(height: 12),
        OrderDetailCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
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
                OrderDetailSummaryRow(
                  label: 'Paid Amount',
                  value: effectivePaid,
                ),
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
                      DateFormat(
                        'd MMM yyyy · HH:mm',
                      ).format(order.paymentTime!),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Payment via',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _methodIcon(order.paymentMethod),
                        size: 13,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        orderDetailHumanize(
                          (order.paymentMethod ?? PaymentMethod.cash).name,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    money0.format(order.totalAmount),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: OrderDetailLabeledDropdown<PaymentStatus>(
                            label: 'STATUS',
                            value: draftPaymentStatus,
                            items: const [
                              PaymentStatus.unpaid,
                              PaymentStatus.paid,
                              PaymentStatus.partial,
                            ],
                            itemLabel: (v) => orderDetailHumanize(v.name),
                            onChanged: onDraftPaymentStatusChanged,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OrderDetailLabeledDropdown<PaymentMethod>(
                            label: 'METHOD',
                            value: draftPaymentMethod,
                            items: const [
                              PaymentMethod.cash,
                              PaymentMethod.upi,
                              PaymentMethod.card,
                              PaymentMethod.online,
                            ],
                            itemLabel: (v) => orderDetailHumanize(v.name),
                            onChanged: onDraftPaymentMethodChanged,
                          ),
                        ),
                      ],
                    ),
                    if (draftPaymentStatus == PaymentStatus.partial) ...[
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AMOUNT PAID',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textLight,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: partialAmountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              hintText: money0.format(order.totalAmount),
                              prefixIcon: const Icon(
                                Icons.currency_rupee_rounded,
                                size: 18,
                                color: AppColors.textLight,
                              ),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: onPartialAmountChanged,
                          ),
                        ],
                      ),
                    ],
                    if (hasPaymentChanges) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: onResetPaymentDrafts,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _onApply(context),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              child: const Text('Update'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
