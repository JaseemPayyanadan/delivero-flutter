import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../app/providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../data/models/order.dart';
import '../order_detail_formatting.dart';
import 'order_detail_surfaces.dart';

/// Bottom sheet for recording payment on an already-delivered order.
Future<void> showOrderDetailUpdatePaymentSheet({
  required BuildContext context,
  required WidgetRef ref,
  required Order order,
}) async {
  final money0 = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: _UpdatePaymentSheet(
        order: order,
        money0: money0,
        onSave: (status, method, amountPaid) {
          final next = order.copyWith(
            paymentStatus: status,
            paymentMethod: method,
            amountPaid: amountPaid,
            paymentTime: status == PaymentStatus.unpaid
                ? null
                : DateTime.now(),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _UpdatePaymentSheet extends StatefulWidget {
  final Order order;
  final NumberFormat money0;
  final void Function(
    PaymentStatus status,
    PaymentMethod method,
    double? amountPaid,
  ) onSave;

  const _UpdatePaymentSheet({
    required this.order,
    required this.money0,
    required this.onSave,
  });

  @override
  State<_UpdatePaymentSheet> createState() => _UpdatePaymentSheetState();
}

class _UpdatePaymentSheetState extends State<_UpdatePaymentSheet> {
  late PaymentStatus _status;
  late PaymentMethod _method;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _status = widget.order.paymentStatus ?? PaymentStatus.unpaid;
    _method = widget.order.paymentMethod ?? PaymentMethod.cash;
    final amount = widget.order.amountPaid ?? 0;
    _amountController = TextEditingController(
      text: _status == PaymentStatus.partial && amount > 0
          ? amount.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final order = widget.order;
    double? amountPaid;
    if (_status == PaymentStatus.unpaid) {
      amountPaid = null;
    } else if (_status == PaymentStatus.paid) {
      amountPaid = order.totalAmount;
    } else {
      final parsed = double.tryParse(
        _amountController.text.trim().replaceAll(',', ''),
      );
      final clamped = (parsed ?? 0).clamp(0.0, order.totalAmount);
      if (clamped <= 0 || clamped >= order.totalAmount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Enter an amount between ${widget.money0.format(1)} and ${widget.money0.format(order.totalAmount - 1)}',
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
    widget.onSave(_status, _method, amountPaid);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Update payment',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Order total ${widget.money0.format(widget.order.totalAmount)}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OrderDetailLabeledDropdown<PaymentStatus>(
                    label: 'STATUS',
                    value: _status,
                    items: const [
                      PaymentStatus.unpaid,
                      PaymentStatus.paid,
                      PaymentStatus.partial,
                    ],
                    itemLabel: (v) => orderDetailHumanize(v.name),
                    onChanged: (v) => setState(() => _status = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OrderDetailLabeledDropdown<PaymentMethod>(
                    label: 'METHOD',
                    value: _method,
                    items: const [
                      PaymentMethod.cash,
                      PaymentMethod.upi,
                      PaymentMethod.card,
                      PaymentMethod.online,
                    ],
                    itemLabel: (v) => orderDetailHumanize(v.name),
                    onChanged: (v) => setState(() => _method = v),
                  ),
                ),
              ],
            ),
            if (_status == PaymentStatus.partial) ...[
              const SizedBox(height: 14),
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
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText: widget.money0.format(widget.order.totalAmount),
                  prefixIcon: const Icon(
                    Icons.currency_rupee_rounded,
                    size: 18,
                    color: AppColors.textLight,
                  ),
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
              child: const Text('Save payment'),
            ),
          ],
        ),
      ),
    );
  }
}
