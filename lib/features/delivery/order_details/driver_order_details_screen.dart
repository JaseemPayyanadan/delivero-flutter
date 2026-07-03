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
import '../../owner/orders/order_details/widgets/order_detail_item_row.dart';
import '../../owner/orders/order_details/widgets/order_detail_payment_section.dart';
import '../../owner/orders/order_details/widgets/order_detail_summary_card.dart';
import '../../owner/orders/order_details/widgets/order_detail_surfaces.dart';

class DriverOrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;

  const DriverOrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<DriverOrderDetailsScreen> createState() =>
      _DriverOrderDetailsScreenState();
}

class _DriverOrderDetailsScreenState
    extends ConsumerState<DriverOrderDetailsScreen> {
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
    final statusBg = orderDetailStatusBg(order.status);
    final statusFg = orderDetailStatusFg(order.status);
    final hasAddress = order.customerAddress.trim().isNotEmpty;

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
                draftPaymentStatus: _draftPaymentStatus ?? PaymentStatus.unpaid,
                draftPaymentMethod: _draftPaymentMethod ?? PaymentMethod.cash,
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
