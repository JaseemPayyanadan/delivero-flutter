import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/maps_launch.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../data/models/order.dart';
import '../driver_order_scope.dart';
import '../../owner/orders/order_details/order_detail_formatting.dart';
import '../../owner/orders/order_details/resolved_order_detail.dart';
import '../../owner/orders/order_details/widgets/confirm_mark_delivered.dart';
import '../../owner/orders/order_details/widgets/order_detail_bottom_actions.dart';
import '../../owner/orders/order_details/widgets/order_detail_customer_card.dart';
import '../../owner/orders/order_details/widgets/order_detail_item_row.dart';
import '../../owner/orders/order_details/widgets/order_detail_payment_section.dart';
import '../../owner/orders/order_details/widgets/order_detail_summary_card.dart';
import '../../owner/orders/order_details/widgets/order_detail_surfaces.dart';
import '../../owner/orders/order_details/widgets/order_detail_update_payment_sheet.dart';

class DriverOrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;

  const DriverOrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<DriverOrderDetailsScreen> createState() =>
      _DriverOrderDetailsScreenState();
}

class _DriverOrderDetailsScreenState
    extends ConsumerState<DriverOrderDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final money0 = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final user = ref.watch(authProvider).user;
    final drivers = ref.watch(driversProvider);
    final driverId = user?.linkedEntityId ?? user?.id;
    final me = drivers.firstWhereOrNull((d) => d.id == driverId);
    final myRouteId = me?.currentRoute?.trim();
    final order = ref
        .watch(ordersProvider)
        .where(
          (o) =>
              canDriverAccessOrder(o, driverId: driverId, routeId: myRouteId),
        )
        .firstWhereOrNull((o) => o.id == widget.orderId);
    final routes = ref.watch(routesProvider);
    final customers = ref.watch(customersProvider);

    if (order == null) {
      return Scaffold(
        appBar: DeliveroAppBar(title: 'Order'),
        body: const Center(child: Text('Order not found')),
      );
    }

    final resolved = ResolvedOrderDetail.compute(order, routes, customers);
    final paymentColor = orderDetailPaymentColor(resolved.paymentStatus);
    final hasAddress = order.customerAddress.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Order Details',
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OrderDetailPillBadge(
                label: orderDetailHumanize(
                  resolved.paymentStatus.name,
                ).toUpperCase(),
                background: paymentColor == AppColors.error
                    ? AppColors.errorLighter.withValues(alpha: 0.68)
                    : paymentColor.withValues(alpha: 0.096),
                foreground: paymentColor,
                border: paymentColor.withValues(alpha: 0.22),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OrderDetailSummaryCard(
                order: order,
                orderIdDisplay: orderDetailDisplayId(order.id),
                money0: money0,
                paymentStatus: resolved.paymentStatus,
                balanceDue: resolved.balanceDue,
              ),
              const SizedBox(height: 24),
              if (order.customerName.trim().isNotEmpty ||
                  order.customerPhone.trim().isNotEmpty ||
                  hasAddress) ...[
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
                          _handleCallCustomer(context, order.customerPhone);
                        },
                  onOpenAddress: hasAddress
                      ? () => _openMaps(context, order.customerAddress)
                      : null,
                ),
                const SizedBox(height: 24),
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
                    for (int idx = 0; idx < order.items.length; idx++) ...[
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
                const OrderDetailSectionHeader(title: 'Notes'),
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
              onMore: () => _showMoreSheet(context, order),
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context, Order order) {
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
            const SizedBox(height: 8),
          ],
        ),
      ),
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
    final digits = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
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
