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
import 'widgets/order_detail_payment_section.dart';
import 'widgets/order_detail_summary_card.dart';
import 'widgets/order_detail_surfaces.dart';

enum _OrderMenuAction { edit, delete }

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;
  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  PaymentStatus? _draftPaymentStatus;
  PaymentMethod? _draftPaymentMethod;
  double? _draftAmountPaid;
  PaymentStatus? _lastServerPaymentStatus;
  PaymentMethod? _lastServerPaymentMethod;
  double? _lastServerAmountPaid;
  final TextEditingController _partialAmountController =
      TextEditingController();

  void _resetPaymentDrafts(Order order) {
    _draftPaymentStatus = order.paymentStatus ?? PaymentStatus.unpaid;
    _draftPaymentMethod = order.paymentMethod ?? PaymentMethod.cash;
    _draftAmountPaid = order.amountPaid;
    _lastServerPaymentStatus = _draftPaymentStatus;
    _lastServerPaymentMethod = _draftPaymentMethod;
    _lastServerAmountPaid = _draftAmountPaid;

    if (_draftPaymentStatus == PaymentStatus.partial) {
      final seed = (_draftAmountPaid ?? 0).clamp(0, order.totalAmount);
      _partialAmountController.text = seed == 0 ? '' : seed.toStringAsFixed(0);
    } else {
      _partialAmountController.clear();
    }
  }

  @override
  void dispose() {
    _partialAmountController.dispose();
    super.dispose();
  }

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

    final serverStatus = order.paymentStatus ?? PaymentStatus.unpaid;
    final serverMethod = order.paymentMethod ?? PaymentMethod.cash;
    final serverAmount = order.amountPaid;
    if (_draftPaymentStatus == null) {
      _draftPaymentStatus = serverStatus;
      _draftPaymentMethod = serverMethod;
      _draftAmountPaid = serverAmount;
      _lastServerPaymentStatus = serverStatus;
      _lastServerPaymentMethod = serverMethod;
      _lastServerAmountPaid = serverAmount;
    } else if (serverStatus != _lastServerPaymentStatus ||
        serverMethod != _lastServerPaymentMethod ||
        serverAmount != _lastServerAmountPaid) {
      _draftPaymentStatus = serverStatus;
      _draftPaymentMethod = serverMethod;
      _draftAmountPaid = serverAmount;
      _lastServerPaymentStatus = serverStatus;
      _lastServerPaymentMethod = serverMethod;
      _lastServerAmountPaid = serverAmount;
      _partialAmountController.text =
          serverStatus == PaymentStatus.partial && (serverAmount ?? 0) > 0
          ? serverAmount!.toStringAsFixed(0)
          : '';
    }
    if ((_draftPaymentStatus ?? PaymentStatus.unpaid) ==
            PaymentStatus.partial &&
        _partialAmountController.text.trim().isEmpty) {
      final seed = (_draftAmountPaid ?? 0).clamp(0, order.totalAmount);
      _partialAmountController.text = seed == 0 ? '' : seed.toStringAsFixed(0);
    }

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
                    OrderDetailSectionHeader(
                      title: 'Items',
                      trailing: '${order.items.length} Items',
                    ),
                    const SizedBox(height: 10),
                    OrderDetailCard(
                      child: Column(
                        children: [
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
                                color: AppColors.border,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    OrderDetailPaymentSection(
                      order: order,
                      money0: money0,
                      paymentStatus: resolved.paymentStatus,
                      paymentColor: paymentColor,
                      deliveryFee: resolved.deliveryFee,
                      effectivePaid: resolved.effectivePaid,
                      balanceDue: resolved.balanceDue,
                      draftPaymentStatus:
                          _draftPaymentStatus ?? PaymentStatus.unpaid,
                      draftPaymentMethod:
                          _draftPaymentMethod ?? PaymentMethod.cash,
                      partialAmountController: _partialAmountController,
                      draftAmountPaid: _draftAmountPaid,
                      onDraftPaymentStatusChanged: (v) => setState(() {
                        _draftPaymentStatus = v;
                        if (v != PaymentStatus.partial) {
                          _draftAmountPaid = null;
                          _partialAmountController.clear();
                        } else {
                          _draftAmountPaid = order.amountPaid;
                        }
                      }),
                      onDraftPaymentMethodChanged: (v) =>
                          setState(() => _draftPaymentMethod = v),
                      onPartialAmountChanged: (val) {
                        final raw = val.trim().replaceAll(',', '');
                        final parsed = double.tryParse(raw);
                        setState(() => _draftAmountPaid = parsed);
                      },
                      onResetPaymentDrafts: () => setState(() {
                        _resetPaymentDrafts(order);
                      }),
                      ref: ref,
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
                    const SizedBox(height: 20),
                    OrderDetailBottomActions(
                      isDelivered: order.status == OrderStatus.delivered,
                      onMarkDelivered: () => showConfirmMarkDeliveredDialog(
                        context: context,
                        ref: ref,
                        order: order,
                        paymentDraft: ConfirmMarkDeliveredPaymentDraft(
                          status: _draftPaymentStatus ?? PaymentStatus.unpaid,
                          method: _draftPaymentMethod ?? PaymentMethod.cash,
                          amountPaid: _draftAmountPaid,
                          partialAmountText: _partialAmountController.text,
                        ),
                      ),
                      onOpenMaps: order.customerAddress.trim().isEmpty
                          ? null
                          : () => _openMaps(context, order.customerAddress),
                      onCancelOrder:
                          (order.status == OrderStatus.cancelled ||
                              order.status == OrderStatus.delivered)
                          ? null
                          : () => _confirmCancelOrder(context, ref, order),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ],
          ),
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

  // ignore: unused_element
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
