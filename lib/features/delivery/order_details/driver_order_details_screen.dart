import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/maps_launch.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../data/models/order.dart';
import '../../owner/orders/order_details/order_detail_formatting.dart';
import '../../owner/orders/order_details/resolved_order_detail.dart';
import '../../owner/orders/order_details/widgets/order_detail_bottom_actions.dart';
import '../../owner/orders/order_details/widgets/order_detail_item_row.dart';
import '../../owner/orders/order_details/widgets/order_detail_summary_card.dart';
import '../../owner/orders/order_details/widgets/order_detail_surfaces.dart';

/// Read-only details view for a driver's assigned order. Drivers can mark
/// the order as delivered, open the address in maps, and tap the customer's
/// phone number to call. Editing/cancelling stays owner-only.
class DriverOrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const DriverOrderDetailsScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final money0 = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final order = ref
        .watch(ordersProvider)
        .firstWhereOrNull((o) => o.id == orderId);
    final routes = ref.watch(routesProvider);
    final customers = ref.watch(customersProvider);

    if (order == null) {
      return Scaffold(
        appBar: DeliveroAppBar(
          title: 'Order',
          leading: Navigator.of(context).canPop()
              ? IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.pop(),
                )
              : null,
        ),
        body: const Center(child: Text('Order not found')),
      );
    }

    final resolved = ResolvedOrderDetail.compute(order, routes, customers);
    final paymentColor = orderDetailPaymentColor(resolved.paymentStatus);
    final statusBg = orderDetailStatusBg(order.status);
    final statusFg = orderDetailStatusFg(order.status);
    final hasAddress = order.customerAddress.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Order Details',
        leading: Navigator.of(context).canPop()
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OrderDetailPillBadge(
                label: orderDetailHumanize(
                  resolved.paymentStatus.name,
                ).toUpperCase(),
                background: paymentColor == AppColors.error
                    ? AppColors.errorLighter.withValues(alpha: 0.85)
                    : paymentColor.withValues(alpha: 0.12),
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
                routeLabel: resolved.summaryRouteLabel,
                paymentStatus: resolved.paymentStatus,
                paymentColor: paymentColor,
                statusBg: statusBg,
                statusFg: statusFg,
                statusLabel: orderDetailHumanize(order.status.name),
                balanceDue: resolved.balanceDue,
                onPhoneTap: order.customerPhone.trim().isEmpty
                    ? null
                    : () {
                        try {
                          HapticFeedback.selectionClick();
                        } catch (_) {}
                        _handleCallCustomer(context, order.customerPhone);
                      },
              ),
              const SizedBox(height: 24),
              if (hasAddress) ...[
                const OrderDetailSectionHeader(title: 'Delivery address'),
                const SizedBox(height: 10),
                _AddressCard(
                  address: order.customerAddress.trim(),
                  onOpenMaps: () => _openMaps(context, order.customerAddress),
                ),
                const SizedBox(height: 24),
              ],
              OrderDetailSectionHeader(
                title: 'Items',
                trailing: '${order.items.length} Items',
              ),
              const SizedBox(height: 10),
              OrderDetailCard(
                child: Column(
                  children: [
                    for (int idx = 0; idx < order.items.length; idx++) ...[
                      OrderDetailItemRow(item: order.items[idx]),
                      if (idx != order.items.length - 1)
                        const Divider(height: 1, color: AppColors.divider),
                    ],
                  ],
                ),
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
              const SizedBox(height: 20),
              OrderDetailBottomActions(
                isDelivered: order.status == OrderStatus.delivered,
                onMarkDelivered: () => _confirmMarkDelivered(
                  context,
                  ref,
                  order,
                ),
                onOpenMaps: hasAddress
                    ? () => _openMaps(context, order.customerAddress)
                    : null,
              ),
              const SizedBox(height: 10),
              SizedBox(height: MediaQuery.paddingOf(context).bottom),
            ],
          ),
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

  void _confirmMarkDelivered(BuildContext context, WidgetRef ref, Order order) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Mark as delivered?',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Confirm that the order for ${order.customerName.trim().isEmpty ? 'this customer' : order.customerName.trim()} has been delivered.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Not yet',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textLight,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              try {
                HapticFeedback.mediumImpact();
              } catch (_) {}
              final updated = order.copyWith(status: OrderStatus.delivered);
              ref.read(ordersProvider.notifier).updateOrder(updated);
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
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text(
              'Confirm',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final String address;
  final VoidCallback onOpenMaps;

  const _AddressCard({required this.address, required this.onOpenMaps});

  @override
  Widget build(BuildContext context) {
    return OrderDetailCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primaryLighter,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                address,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open in maps',
            onPressed: onOpenMaps,
            icon: const Icon(
              Icons.navigation_rounded,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
