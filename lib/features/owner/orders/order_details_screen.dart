import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order.dart';
import '../../../data/models/delivery_route.dart';
import '../../../data/models/driver.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref
        .watch(ordersProvider)
        .firstWhereOrNull((o) => o.id == orderId);
    final routes = ref.watch(routesProvider);
    final drivers = ref.watch(driversProvider);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.backgroundPrimary),
        body: const Center(child: Text('Order not found')),
      );
    }

    final route = routes.firstWhereOrNull(
      (r) => r.id == order.assignedRoute || r.name == order.assignedRoute,
    );
    final driver = drivers.firstWhereOrNull(
      (d) => d.id == order.assignedDriver,
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'TXN: ${order.id.toUpperCase()}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _handleDelete(context, ref, order),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(order),
            const SizedBox(height: 22),
            _buildSectionTitle('FULFILLMENT MANIFEST'),
            _buildFulfillmentCard(order, route, driver),
            const SizedBox(height: 22),
            _buildSectionTitle('INVENTORY MANIFEST'),
            _buildItemsSummary(order),
            const SizedBox(height: 22),
            _buildSectionTitle('FINANCIAL SETTLEMENT'),
            _buildPaymentSection(context, ref, order),
            const SizedBox(height: 22),
            _buildSectionTitle('OPERATIONAL STATUS'),
            _buildUpdateStatus(context, ref, order),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.textLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildStatusHeader(Order order) {
    final statusColor = _getStatusColor(order.status);
    final dateStr = DateFormat('MMM d, yyyy').format(order.orderDate);
    final timeStr = DateFormat('hh:mm a').format(order.orderDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRANSACTION VALUE',
                      style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '₹${NumberFormat.decimalPattern().format(order.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          letterSpacing: -1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: _StatusBadge(
                  label: order.status.name.toUpperCase(),
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildHeaderMeta(
                Icons.calendar_today_rounded,
                dateStr,
                'PLACEMENT DATE',
              ),
              Container(
                width: 1,
                height: 22,
                color: AppColors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              _buildHeaderMeta(
                Icons.access_time_rounded,
                timeStr,
                'ORDER TIME',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMeta(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.w900,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(icon, size: 11, color: AppColors.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFulfillmentCard(
    Order order,
    DeliveryRoute? route,
    Driver? driver,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 11,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            order.customerPhone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                onPressed: () {
                  // TODO: Implement direct call logic
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.backgroundSecondary,
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.all(10),
                ),
                icon: const Icon(Icons.call_rounded, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.map_rounded,
                size: 13,
                color: AppColors.textLight,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.customerAddress,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          Row(
            children: [
              Expanded(
                child: _buildLogisticsItem(
                  Icons.alt_route_rounded,
                  'LOGISTICS ROUTE',
                  route?.name ?? order.assignedRoute ?? 'PENDING',
                  AppColors.primary,
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: AppColors.divider,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _buildLogisticsItem(
                  Icons.person_pin_circle_rounded,
                  'FIELD AGENT',
                  driver?.name ?? 'DISPATCH PENDING',
                  AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsItem(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.w900,
                color: AppColors.textLight,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSummary(Order order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLighter,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${item.quantity}x',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.foodItemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    '₹${NumberFormat.decimalPattern().format(item.totalPrice)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Subtotal Manifest',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              Text(
                '₹${NumberFormat.decimalPattern().format(order.subtotal)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditAmountPaid(BuildContext context, WidgetRef ref, Order order) {
    final controller = TextEditingController(
      text: (order.amountPaid ?? 0).toStringAsFixed(0),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Update Payment',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TOTAL DUE: ₹${order.totalAmount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixText: '₹ ',
                filled: true,
                fillColor: AppColors.backgroundSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              PaymentStatus status = PaymentStatus.unpaid;
              if (amount >= order.totalAmount) {
                status = PaymentStatus.paid;
              } else if (amount > 0) {
                status = PaymentStatus.partial;
              }

              final updatedOrder = order.copyWith(
                amountPaid: amount,
                paymentStatus: status,
              );
              ref.read(ordersProvider.notifier).updateOrder(updatedOrder);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'SAVE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection(
    BuildContext context,
    WidgetRef ref,
    Order order,
  ) {
    final paymentStatus = order.paymentStatus ?? PaymentStatus.unpaid;
    final paymentColor = _getPaymentStatusColor(paymentStatus);
    final paymentMethod = order.paymentMethod ?? PaymentMethod.cash;
    final totalAmount = order.totalAmount;
    final amountPaid = order.amountPaid ?? 0.0;
    final amountDue = (totalAmount - amountPaid).clamp(0.0, double.infinity);
    final progress = totalAmount <= 0
        ? 0.0
        : (amountPaid / totalAmount).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'SETTLEMENT OVERVIEW',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textLight,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: paymentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: paymentColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: paymentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      paymentStatus.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: paymentColor,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _AmountMetric(
                    label: 'TOTAL',
                    value: totalAmount,
                    color: AppColors.secondary,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.divider,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _AmountMetric(
                    label: 'PAID',
                    value: amountPaid,
                    color: paymentColor,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: AppColors.divider,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                ),
                Expanded(
                  child: _AmountMetric(
                    label: 'DUE',
                    value: amountDue,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(paymentColor),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textLight,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PaymentStatus>(
                          value: paymentStatus,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                          onChanged: (val) {
                            if (val == null) return;
                            double nextPaid = amountPaid;
                            if (val == PaymentStatus.paid) {
                              nextPaid = totalAmount;
                            } else if (val == PaymentStatus.unpaid) {
                              nextPaid = 0.0;
                            }
                            ref
                                .read(ordersProvider.notifier)
                                .updateOrder(
                                  order.copyWith(
                                    paymentStatus: val,
                                    amountPaid: nextPaid,
                                  ),
                                );
                          },
                          items: PaymentStatus.values
                              .map(
                                (s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s.name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: _getPaymentStatusColor(s),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'METHOD',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textLight,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PaymentMethod>(
                          value: paymentMethod,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                          onChanged: (val) {
                            if (val == null) return;
                            ref
                                .read(ordersProvider.notifier)
                                .updateOrder(
                                  order.copyWith(paymentMethod: val),
                                );
                          },
                          items: PaymentMethod.values
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        m == PaymentMethod.upi
                                            ? Icons
                                                  .account_balance_wallet_rounded
                                            : m == PaymentMethod.cash
                                            ? Icons.payments_rounded
                                            : m == PaymentMethod.card
                                            ? Icons.credit_card_rounded
                                            : Icons.language_rounded,
                                        size: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        m.name.toUpperCase(),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.textPrimary,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showEditAmountPaid(context, ref, order),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.edit_document, size: 16),
              label: const Text(
                'UPDATE AMOUNT',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateStatus(BuildContext context, WidgetRef ref, Order order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusStep(
                context,
                ref,
                order,
                OrderStatus.pending,
                'QUEUED',
                Icons.inventory_2_outlined,
                Icons.inventory_2_rounded,
              ),
              _buildStatusConnector(order.status == OrderStatus.delivered),
              _buildStatusStep(
                context,
                ref,
                order,
                OrderStatus.delivered,
                'FULFILLED',
                Icons.task_alt_outlined,
                Icons.task_alt_rounded,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (order.status == OrderStatus.cancelled)
            Container(
              padding: const EdgeInsets.all(14),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'TRANSACTION VOIDED',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: order.status == OrderStatus.delivered
                        ? null
                        : () => _handleStatusChange(
                            context,
                            ref,
                            order,
                            OrderStatus.delivered,
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      disabledBackgroundColor: AppColors.border.withValues(
                        alpha: 0.7,
                      ),
                      disabledForegroundColor: AppColors.textLight,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text(
                      'MARK DELIVERED',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _handleStatusChange(
                      context,
                      ref,
                      order,
                      OrderStatus.cancelled,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.block_flipped, size: 16),
                    label: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _handleDelete(context, ref, order),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text(
                'DELETE ORDER',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusStep(
    BuildContext context,
    WidgetRef ref,
    Order order,
    OrderStatus stepStatus,
    String label,
    IconData icon,
    IconData activeIcon,
  ) {
    final bool isCurrent = order.status == stepStatus;
    final bool isCompleted =
        order.status == OrderStatus.delivered &&
        stepStatus == OrderStatus.pending;
    final Color color = isCurrent || isCompleted
        ? _getStatusColor(stepStatus)
        : AppColors.textDisabled;

    return Expanded(
      child: InkWell(
        onTap: () => _handleStatusChange(context, ref, order, stepStatus),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isCurrent ? 0.15 : 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: isCurrent ? 1.0 : 0.2),
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : (isCurrent ? activeIcon : icon),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: isCurrent ? AppColors.textPrimary : AppColors.textLight,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusConnector(bool isActive) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isActive ? AppColors.success : AppColors.border,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }

  void _handleStatusChange(
    BuildContext context,
    WidgetRef ref,
    Order order,
    OrderStatus newStatus,
  ) {
    if (order.status == newStatus) return;

    final updatedOrder = order.copyWith(status: newStatus);
    ref.read(ordersProvider.notifier).updateOrder(updatedOrder);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Order status updated to ${newStatus.name.toUpperCase()}',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _getStatusColor(newStatus),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _handleDelete(BuildContext context, WidgetRef ref, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete Transaction?',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'This action will permanently remove this record from your ledger.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(ordersProvider.notifier).deleteOrder(order.id);
              context.pop(); // Close dialog
              context.pop(); // Close details screen
            },
            child: const Text(
              'DELETE RECORD',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Color _getPaymentStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppColors.success;
      case PaymentStatus.partial:
        return AppColors.warning;
      case PaymentStatus.unpaid:
        return AppColors.error;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _AmountMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textLight,
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '₹${NumberFormat.decimalPattern().format(value)}',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}
