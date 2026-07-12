import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/maps_launch.dart';
import '../../../../core/widgets/delivero_gradient_header.dart';
import '../../../../core/widgets/delivero_sliver_header.dart';
import '../../../../data/models/order.dart';
import 'order_detail_formatting.dart';
import 'resolved_order_detail.dart';
import 'widgets/confirm_mark_delivered.dart';
import 'widgets/order_detail_bottom_actions.dart';
import 'widgets/order_detail_item_row.dart';
import 'widgets/order_detail_customer_card.dart';
import 'widgets/order_detail_payment_section.dart';
import 'widgets/order_detail_summary_card.dart';
import 'widgets/order_detail_surfaces.dart';
import 'widgets/order_detail_update_payment_sheet.dart';

enum _OrderMenuAction { edit, delete }

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final money0 = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final order = ref
        .watch(ordersProvider)
        .firstWhereOrNull((o) => o.id == widget.orderId);
    final routes = ref.watch(routesProvider);
    final customers = ref.watch(customersProvider);

    if (order == null) {
      return Scaffold(
        appBar: const DeliveroAppBar(title: 'Order'),
        body: const Center(child: Text('Order not found')),
      );
    }

    final resolved = ResolvedOrderDetail.compute(order, routes, customers);
    final paymentColor = orderDetailPaymentColor(resolved.paymentStatus);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeliveroGradientHeader(
                title: 'Order Details',
                subtitle: orderDetailDisplayId(order.id),
                onBack: Navigator.of(context).canPop()
                    ? () => context.pop()
                    : null,
                horizontalPadding: 20,
                bannerHeight: 104,
                overlap: 36,
                actions: [_buildOverflowMenu(context, ref, order)],
                overlapChild: OrderDetailSummaryCard(
                  order: order,
                  orderIdDisplay: orderDetailDisplayId(order.id),
                  money0: money0,
                  paymentStatus: resolved.paymentStatus,
                  balanceDue: resolved.balanceDue,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (order.customerName.trim().isNotEmpty ||
                        order.customerPhone.trim().isNotEmpty ||
                        order.customerAddress.trim().isNotEmpty) ...[
                      OrderDetailCustomerCard(
                        name: order.customerName,
                        phone: order.customerPhone,
                        address: order.customerAddress,
                        routeLabel: resolved.summaryRouteLabel,
                        onCall: order.customerPhone.trim().isEmpty
                            ? null
                            : () {
                                try {
                                  HapticFeedback.selectionClick();
                                } catch (_) {}
                                _handleCallCustomer(
                                  context,
                                  order.customerPhone,
                                );
                              },
                        onOpenAddress: order.customerAddress.trim().isEmpty
                            ? null
                            : () => _openMaps(context, order.customerAddress),
                        onViewCustomer: order.customerId.trim().isEmpty
                            ? null
                            : () => context.push(
                                '/owner/customers/${order.customerId}',
                              ),
                      ),
                      const SizedBox(height: 22),
                    ],
                    OrderDetailCard(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OrderDetailSectionHeader(
                            title: 'Items',
                            trailing:
                                '${order.items.length} ${order.items.length == 1 ? 'Item' : 'Items'}',
                          ),
                          const SizedBox(height: 4),
                          for (
                            int idx = 0;
                            idx < order.items.length;
                            idx++
                          ) ...[
                            OrderDetailItemRow(item: order.items[idx]),
                            if (idx != order.items.length - 1)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: AppColors.divider,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    OrderDetailPaymentCard(
                      order: order,
                      money0: money0,
                      paymentStatus: resolved.paymentStatus,
                      paymentColor: paymentColor,
                      deliveryFee: resolved.deliveryFee,
                      effectivePaid: resolved.effectivePaid,
                      balanceDue: resolved.balanceDue,
                      onUpdatePayment:
                          order.status == OrderStatus.delivered &&
                              resolved.paymentStatus != PaymentStatus.paid
                          ? () => showOrderDetailUpdatePaymentSheet(
                              context: context,
                              ref: ref,
                              order: order,
                            )
                          : null,
                    ),
                    if ((order.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const OrderDetailSectionHeader(
                        title: 'Notes',
                        icon: Icons.sticky_note_2_rounded,
                      ),
                      const SizedBox(height: 10),
                      OrderDetailCard(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          order.notes!.trim(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    if (order.status != OrderStatus.delivered &&
                        order.status != OrderStatus.cancelled) ...[
                      const SizedBox(height: 18),
                      const _PaymentInfoBanner(),
                    ],
                    SizedBox(height: MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: OrderDetailBottomBar(
              isDelivered: order.status == OrderStatus.delivered,
              onMarkDelivered: () => showConfirmMarkDeliveredDialog(
                context: context,
                ref: ref,
                order: order,
              ),
              onMore: () => _showMoreSheet(context, ref, order),
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context, WidgetRef ref, Order order) {
    final canEdit =
        order.status != OrderStatus.delivered &&
        order.status != OrderStatus.cancelled;
    final canCancel = canEdit;
    final hasAddress = order.customerAddress.trim().isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasAddress)
              ListTile(
                leading: const Icon(
                  Icons.navigation_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Navigate to address',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openMaps(context, order.customerAddress);
                },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.textSecondary,
                ),
                title: const Text(
                  'Edit order',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/owner/orders/edit/${order.id}');
                },
              ),
            if (canCancel)
              ListTile(
                leading: const Icon(
                  Icons.close_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Cancel order',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmCancelOrder(context, ref, order);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.error,
              ),
              title: const Text(
                'Delete order',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.error,
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _handleDelete(context, ref, order);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOverflowMenu(BuildContext context, WidgetRef ref, Order order) {
    return PopupMenuButton<_OrderMenuAction>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
      onSelected: (action) {
        switch (action) {
          case _OrderMenuAction.edit:
            context.push('/owner/orders/edit/${order.id}');
            break;
          case _OrderMenuAction.delete:
            _handleDelete(context, ref, order);
        }
      },
      itemBuilder: (context) {
        final canEdit =
            order.status != OrderStatus.delivered &&
            order.status != OrderStatus.cancelled;
        return [
          if (canEdit)
            const PopupMenuItem(
              value: _OrderMenuAction.edit,
              child: Text('Edit order'),
            ),
          const PopupMenuItem(
            value: _OrderMenuAction.delete,
            child: Text('Delete order'),
          ),
        ];
      },
    );
  }

  Future<void> _openMaps(BuildContext context, String address) async {
    final ok = await openMapsForAddress(address);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not open maps',
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
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
    final now = DateTime.now();
    final updatedOrder = order.copyWith(
      status: newStatus,
      deliveryTime: newStatus == OrderStatus.delivered
          ? (order.deliveryTime ?? now)
          : order.deliveryTime,
      deliveryDate: newStatus == OrderStatus.delivered
          ? (order.deliveryDate ?? now)
          : order.deliveryDate,
    );
    ref.read(ordersProvider.notifier).updateOrder(updatedOrder);
    ref
        .read(lastTouchedOrderProvider.notifier)
        .set(id: updatedOrder.id, wasCreated: false);

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order is now ${orderDetailHumanize(newStatus.name)}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: orderDetailStatusAccent(newStatus),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _confirmCancelOrder(BuildContext context, WidgetRef ref, Order order) {
    if (order.status == OrderStatus.cancelled) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Cancel this order?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'The order will be marked as cancelled. You can still view it in your list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Keep order',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _handleStatusChange(context, ref, order, OrderStatus.cancelled);
            },
            child: const Text(
              'Cancel order',
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

  void _handleDelete(BuildContext context, WidgetRef ref, Order order) {
    final screenContext = context;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Keep it',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(ordersProvider.notifier).deleteOrder(order.id);
              } catch (_) {
                if (screenContext.mounted) {
                  ScaffoldMessenger.of(screenContext).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Failed to delete order. Check your connection.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                  return;
                }
              }
              if (screenContext.mounted) screenContext.pop();
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

class _PaymentInfoBanner extends StatelessWidget {
  const _PaymentInfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_rounded, size: 20, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'You can update payment details after marking the order as delivered.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
