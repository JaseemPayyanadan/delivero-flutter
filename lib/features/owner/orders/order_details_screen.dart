import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

// ignore_for_file: use_null_aware_elements

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../data/models/delivery_route.dart';
import '../../../data/models/order.dart';

String _humanizeWord(String raw) {
  if (raw.isEmpty) return raw;
  return raw[0].toUpperCase() + raw.substring(1);
}

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref
        .watch(ordersProvider)
        .firstWhereOrNull((o) => o.id == orderId);
    final routes = ref.watch(routesProvider);

    if (order == null) {
      return Scaffold(
        appBar: const DeliveroAppBar(title: 'Order'),
        body: const Center(child: Text('Order not found')),
      );
    }

    final route = routes.firstWhereOrNull(
      (r) => r.id == order.assignedRoute || r.name == order.assignedRoute,
    );

    final statusColor = _getStatusColor(order.status);
    final paymentStatus = order.paymentStatus ?? PaymentStatus.unpaid;
    final paymentColor = _getPaymentStatusColor(paymentStatus);

    // Best-effort approximation for "Delivery Fee" row in the screenshot.
    final deliveryFee =
        (order.totalAmount - order.subtotal + order.discountAmount).clamp(
          0.0,
          double.infinity,
        );

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Order Details',
        centerTitle: true,
        actions: [
          PopupMenuButton<_OrderMenuAction>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (action) {
              switch (action) {
                case _OrderMenuAction.delete:
                  _handleDelete(context, ref, order);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _OrderMenuAction.delete,
                child: Text('Delete order'),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      bottomNavigationBar: _BottomActions(
        isDelivered: order.status == OrderStatus.delivered,
        onMarkDelivered: () =>
            _handleStatusChange(context, ref, order, OrderStatus.delivered),
        onCallCustomer: () => _handleCallCustomer(context, order.customerPhone),
        onCancelOrder: () =>
            _handleStatusChange(context, ref, order, OrderStatus.cancelled),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #-${order.id}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Current Order\nOverview',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          height: 1.05,
                          letterSpacing: -1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(
                  label: _humanizeWord(order.status.name),
                  color: statusColor,
                  compact: false,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CustomerOverviewCard(order: order, route: route),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Order Items',
              trailing: '${order.items.length} Items',
            ),
            const SizedBox(height: 10),
            _Card(
              child: Column(
                children: [
                  for (int idx = 0; idx < order.items.length; idx++) ...[
                    _OrderItemRow(item: order.items[idx]),
                    if (idx != order.items.length - 1)
                      const Divider(height: 1, color: AppColors.divider),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            _SectionHeader(
              title: 'Payment Summary',
              trailingWidget: _PillBadge(
                label: _humanizeWord(paymentStatus.name),
                background: paymentColor.withValues(alpha: 0.12),
                foreground: paymentColor,
              ),
            ),
            const SizedBox(height: 10),
            _Card(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _SummaryRow(label: 'Subtotal', value: order.subtotal),
                  const SizedBox(height: 10),
                  _SummaryRow(label: 'Delivery Fee', value: deliveryFee),
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
                        '₹${order.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 90), // breathing space above bottom actions
          ],
        ),
      ),
    );
  }

  Future<void> _handleCallCustomer(BuildContext context, String phone) async {
    final raw = phone.trim();
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Phone number not available',
            style: TextStyle(fontWeight: FontWeight.w700),
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
    final uri = Uri(scheme: 'tel', path: digits);
    final ok = await launchUrl(uri);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to start call',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
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
        content: Text('Order is now ${_humanizeWord(newStatus.name)}'),
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
          'Delete this order?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This removes the order from your list. You cannot undo it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Keep it',
              style: TextStyle(
                fontWeight: FontWeight.w700,
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
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _OrderMenuAction { delete }

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

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
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
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget? trailingWidget;

  const _SectionHeader({
    required this.title,
    this.trailing,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (trailingWidget != null) trailingWidget!,
        if (trailingWidget == null && trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 0.1,
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool compact;

  const _StatusBadge({
    required this.label,
    required this.color,
    this.compact = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  final String label;
  final Widget? leading;
  final Color background;
  final Color foreground;
  final Color? border;

  const _PillBadge({
    required this.label,
    this.leading,
    required this.background,
    required this.foreground,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: border == null ? null : Border.all(color: border!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerOverviewCard extends StatelessWidget {
  final Order order;
  final DeliveryRoute? route;

  const _CustomerOverviewCard({required this.order, required this.route});

  @override
  Widget build(BuildContext context) {
    final routeLabel = route?.name ?? order.assignedRoute ?? 'Not set';

    return _Card(
      padding: const EdgeInsets.all(18),
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
                  Icons.person_rounded,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          size: 12,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
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
            ],
          ),
          const SizedBox(height: 12),
          _PillBadge(
            label: routeLabel,
            leading: const Icon(
              Icons.near_me_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            background: AppColors.backgroundSecondary,
            foreground: AppColors.textPrimary,
            border: AppColors.border,
          ),
        ],
      ),
    );
  }
}

class _OrderItemRow extends StatelessWidget {
  final OrderItem item;

  const _OrderItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              shape: BoxShape.circle,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.foodItemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Item',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '₹${item.totalPrice.toStringAsFixed(0)}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
        Text(
          '₹${value.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool isDelivered;
  final VoidCallback onMarkDelivered;
  final VoidCallback onCallCustomer;
  final VoidCallback onCancelOrder;

  const _BottomActions({
    required this.isDelivered,
    required this.onMarkDelivered,
    required this.onCallCustomer,
    required this.onCancelOrder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isDelivered ? null : onMarkDelivered,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  disabledBackgroundColor: AppColors.border,
                  disabledForegroundColor: AppColors.textLight,
                ),
                icon: const Icon(Icons.check_circle_rounded, size: 18),
                label: const Text(
                  'Mark as Delivered',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onCallCustomer,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.backgroundSecondary,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: AppColors.border),
                  ),
                ),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text(
                  'Call Customer',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onCancelOrder,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Cancel Order'),
            ),
          ],
        ),
      ),
    );
  }
}
