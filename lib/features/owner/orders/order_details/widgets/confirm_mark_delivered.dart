import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/order.dart';
import '../order_detail_formatting.dart';

/// Payment fields from the order details form when marking delivered.
class ConfirmMarkDeliveredPaymentDraft {
  final PaymentStatus status;
  final PaymentMethod method;
  final double? amountPaid;
  final String? partialAmountText;

  const ConfirmMarkDeliveredPaymentDraft({
    required this.status,
    required this.method,
    this.amountPaid,
    this.partialAmountText,
  });
}

double? _resolveAmountPaid({
  required Order order,
  required PaymentStatus status,
  required double? amountPaid,
  required String? partialAmountText,
}) {
  return switch (status) {
    PaymentStatus.unpaid => null,
    PaymentStatus.paid => order.totalAmount,
    PaymentStatus.partial => () {
      final raw = partialAmountText?.trim().replaceAll(',', '');
      final parsed = raw == null || raw.isEmpty
          ? amountPaid
          : double.tryParse(raw) ?? amountPaid;
      if (parsed == null) return null;
      return parsed.clamp(0.0, order.totalAmount);
    }(),
  };
}

double _effectivePaid(Order order, PaymentStatus status, double? amountPaid) {
  return switch (status) {
    PaymentStatus.paid => order.totalAmount,
    PaymentStatus.partial => (amountPaid ?? 0).clamp(0.0, order.totalAmount),
    PaymentStatus.unpaid => 0,
  };
}

String? _partialValidationMessage(
  Order order,
  PaymentStatus status,
  double? amountPaid,
  NumberFormat money0,
) {
  if (status != PaymentStatus.partial) return null;
  final paid = amountPaid;
  if (paid == null) {
    return 'Enter the amount collected for a partial payment.';
  }
  if (paid <= 0 || paid >= order.totalAmount) {
    return 'Partial amount must be between ${money0.format(1)} and ${money0.format(order.totalAmount - 1)}.';
  }
  return null;
}

/// Asks the user to verify payment before marking [order] as delivered.
Future<void> showConfirmMarkDeliveredDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Order order,
  ConfirmMarkDeliveredPaymentDraft? paymentDraft,
}) async {
  if (order.status == OrderStatus.delivered) return;

  final draft =
      paymentDraft ??
      ConfirmMarkDeliveredPaymentDraft(
        status: order.paymentStatus ?? PaymentStatus.unpaid,
        method: order.paymentMethod ?? PaymentMethod.cash,
        amountPaid: order.amountPaid,
      );

  await showDialog<void>(
    context: context,
    builder: (ctx) => _ConfirmMarkDeliveredDialog(
      order: order,
      paymentDraft: draft,
      onConfirm: (updatedOrder) async {
        try {
          await ref.read(ordersProvider.notifier).updateOrder(updatedOrder);
          ref
              .read(lastTouchedOrderProvider.notifier)
              .set(id: updatedOrder.id, wasCreated: false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Order marked as delivered',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
            try {
              HapticFeedback.heavyImpact();
            } catch (_) {}
          }
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to update order. Check your connection.'),
                backgroundColor: Color(0xFFD32F2F),
              ),
            );
          }
        }
      },
    ),
  );
}

class _ConfirmMarkDeliveredDialog extends StatefulWidget {
  final Order order;
  final ConfirmMarkDeliveredPaymentDraft paymentDraft;
  final Future<void> Function(Order updatedOrder) onConfirm;

  const _ConfirmMarkDeliveredDialog({
    required this.order,
    required this.paymentDraft,
    required this.onConfirm,
  });

  @override
  State<_ConfirmMarkDeliveredDialog> createState() =>
      _ConfirmMarkDeliveredDialogState();
}

class _ConfirmMarkDeliveredDialogState
    extends State<_ConfirmMarkDeliveredDialog> {
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final draft = widget.paymentDraft;
    final money0 = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final resolvedAmount = _resolveAmountPaid(
      order: order,
      status: draft.status,
      amountPaid: draft.amountPaid,
      partialAmountText: draft.partialAmountText,
    );
    final validationError = _partialValidationMessage(
      order,
      draft.status,
      resolvedAmount,
      money0,
    );
    final effectivePaid = _effectivePaid(order, draft.status, resolvedAmount);
    final balanceDue = (order.totalAmount - effectivePaid).clamp(
      0.0,
      double.infinity,
    );
    final paymentColor = orderDetailPaymentColor(draft.status);
    final statusLabel = orderDetailHumanize(draft.status.name);
    final methodLabel = orderDetailHumanize(draft.method.name);
    final customerLabel = order.customerName.trim().isEmpty
        ? 'Customer'
        : order.customerName.trim();
    final canConfirm = validationError == null && !_isSaving;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Check payment',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Verify payment for $customerLabel before marking this order as delivered.',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _PaymentCheckRow(
                    label: 'Order total',
                    value: money0.format(order.totalAmount),
                    valueStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PaymentCheckRow(
                    label: 'Payment status',
                    valueWidget: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: paymentColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: paymentColor.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: paymentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  if (draft.status != PaymentStatus.unpaid) ...[
                    const SizedBox(height: 10),
                    _PaymentCheckRow(
                      label: 'Collected',
                      value: money0.format(effectivePaid),
                      valueColor: AppColors.success,
                    ),
                  ],
                  if (balanceDue > 0.004) ...[
                    const SizedBox(height: 10),
                    _PaymentCheckRow(
                      label: 'Balance due',
                      value: money0.format(balanceDue),
                      valueColor: AppColors.error,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _PaymentCheckRow(label: 'Payment via', value: methodLabel),
                ],
              ),
            ),
            if (validationError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLighter.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        validationError,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (balanceDue > 0.004) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warningLighter.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.warning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${money0.format(balanceDue)} is still unpaid. You can deliver now and collect later.',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text(
            'Go back',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
            ),
          ),
        ),
        FilledButton(
          onPressed: canConfirm
              ? () async {
                  setState(() => _isSaving = true);
                  try {
                    HapticFeedback.mediumImpact();
                  } catch (_) {}
                  final now = DateTime.now();
                  final amountPaid = resolvedAmount;
                  final updated = order.copyWith(
                    status: OrderStatus.delivered,
                    deliveryTime: order.deliveryTime ?? now,
                    deliveryDate: order.deliveryDate ?? now,
                    paymentStatus: draft.status,
                    paymentMethod: draft.method,
                    amountPaid: amountPaid,
                    paymentTime: draft.status == PaymentStatus.unpaid
                        ? order.paymentTime
                        : (order.paymentTime ?? now),
                    updatedAt: now,
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await widget.onConfirm(updated);
                }
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: canConfirm
                ? AppColors.success
                : AppColors.success.withValues(alpha: 0.45),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Mark delivered',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
        ),
      ],
    );
  }
}

class _PaymentCheckRow extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color? valueColor;
  final TextStyle? valueStyle;

  const _PaymentCheckRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (valueWidget != null)
          valueWidget!
        else
          Text(
            value ?? '—',
            style:
                valueStyle ??
                TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
          ),
      ],
    );
  }
}
