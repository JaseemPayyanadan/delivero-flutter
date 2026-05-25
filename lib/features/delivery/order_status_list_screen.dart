import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../data/models/order.dart';
import 'driver_order_scope.dart';

class OrderStatusListScreen extends ConsumerStatefulWidget {
  const OrderStatusListScreen({super.key});

  @override
  ConsumerState<OrderStatusListScreen> createState() =>
      _OrderStatusListScreenState();
}

class _OrderStatusListScreenState extends ConsumerState<OrderStatusListScreen> {
  String _selectedStatus = 'all';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _formatRupee(double amount) {
    final whole = amount == amount.roundToDouble();
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: whole ? 0 : 2,
    ).format(amount);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openSearchSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AssignedOrdersSearchSheet(
          controller: _searchController,
          onChanged: (q) => setState(() => _searchQuery = q),
          onClear: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final allOrders = ref.watch(ordersProvider);
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final isLoading = !ordersLoaded && allOrders.isEmpty;

    final driverId = user?.linkedEntityId ?? user?.id;
    final drivers = ref.watch(driversProvider);
    final me = drivers.firstWhereOrNull((d) => d.id == driverId);
    final myRouteId = me?.currentRoute?.trim();
    final myAllOrders = driverScopedOrders(
      allOrders,
      driverId: driverId,
      routeId: myRouteId,
    );
    var myOrders = List<Order>.from(myAllOrders);

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      final qRaw = _searchQuery.trim();
      myOrders = myOrders.where((o) {
        return o.customerName.toLowerCase().contains(q) ||
            o.id.toLowerCase().contains(q) ||
            o.customerPhone.contains(qRaw) ||
            o.customerAddress.toLowerCase().contains(q) ||
            o.customerEmail.toLowerCase().contains(q);
      }).toList();
    }

    // Filter by status tab
    if (_selectedStatus == 'all') {
      myOrders = myOrders.where(isDriverActiveOrder).toList();
    } else if (_selectedStatus == 'delivered') {
      myOrders = myOrders
          .where((o) => o.status == OrderStatus.delivered)
          .toList();
    }

    myOrders.sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      if (c != 0) return c;
      return a.orderDate.compareTo(b.orderDate);
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Assigned Orders',
        leading: null,
        actions: [
          IconButton(
            tooltip: 'New order',
            onPressed: () => context.push('/delivery/new-order'),
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            tooltip: 'Search',
            onPressed: () => _openSearchSheet(context),
            icon: const Icon(
              Icons.search_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: _buildFilters(myAllOrders)),
            if (isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (myOrders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(hasAnyAssigned: myAllOrders.isNotEmpty),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildOrderCard(context, ref, myOrders[index]),
                    childCount: myOrders.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(List<Order> myAllOrders) {
    final activeCount = myAllOrders.where(isDriverActiveOrder).length;
    final deliveredCount = myAllOrders
        .where((o) => o.status == OrderStatus.delivered)
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatusPill('all', 'Active ($activeCount)'),
            _buildStatusPill('delivered', 'Delivered ($deliveredCount)'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String key, String label) {
    final isSelected = _selectedStatus == key;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => setState(() => _selectedStatus = key),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }

  String _displayOrderId(String rawId) {
    final id = rawId.trim();
    if (id.isEmpty) return '#ORD-—';
    final upper = id.toUpperCase();
    if (upper.startsWith('ORD-') || upper.startsWith('#ORD-')) {
      return upper.startsWith('#') ? upper : '#$upper';
    }
    final short = upper.length > 4 ? upper.substring(0, 4) : upper;
    return '#ORD-$short';
  }

  String _humanStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Out for delivery';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
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

  Color _chipTextColor(Color base) {
    final hsl = HSLColor.fromColor(base);
    if (hsl.lightness > 0.6) {
      return hsl.withLightness(0.35).toColor();
    }
    return base;
  }

  Color _getPaymentColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppColors.success;
      case PaymentStatus.partial:
        return AppColors.warning;
      case PaymentStatus.unpaid:
        return AppColors.error;
    }
  }

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, Order order) {
    final lastTouched = ref.watch(lastTouchedOrderProvider);
    final shouldHighlight =
        lastTouched != null &&
        lastTouched.id == order.id &&
        DateTime.now().difference(lastTouched.at) <= const Duration(seconds: 8);
    final highlightColor = lastTouched?.wasCreated == true
        ? AppColors.success
        : AppColors.primary;

    final customerName = order.customerName.trim().isEmpty
        ? 'Unknown'
        : order.customerName.trim();
    final displayId = _displayOrderId(order.id);
    final dateLabel = DateFormat('EEE, d MMM').format(order.orderDate);
    final metaLine = '$displayId · $dateLabel';
    final typeKind = switch (order.orderType) {
      OrderType.daily => 'Daily',
      OrderType.oneTime => 'One-time',
      OrderType.special => 'Special',
    };
    final typeLabel = '${order.deliveryRun.label} · $typeKind';

    final statusText = _humanStatus(order.status);
    final statusColor = _getStatusColor(order.status);
    final statusChipBase = switch (order.status) {
      OrderStatus.pending => AppColors.warning,
      _ => statusColor,
    };
    final statusChipBg = statusChipBase.withValues(alpha: 0.32);
    final statusChipFg = _chipTextColor(statusChipBase);
    final payment = order.paymentStatus ?? PaymentStatus.unpaid;
    final paymentColor = _getPaymentColor(payment);
    final paymentChipFg = _chipTextColor(paymentColor);
    final paymentLabel = switch (payment) {
      PaymentStatus.paid => 'Paid',
      PaymentStatus.partial => 'Partial',
      PaymentStatus.unpaid => 'Unpaid',
    };
    const previewMax = 3;
    final previewItems = order.items.take(previewMax).toList();
    final moreLines = order.items.length - previewItems.length;
    const emptyLineItemsText = '—';
    final lineItemParts = previewItems.isEmpty
        ? const <String>[]
        : [
            ...previewItems.map((i) => '${i.foodItemName} x${i.quantity}'),
            if (moreLines > 0) '+$moreLines more',
          ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: shouldHighlight
            ? highlightColor.withValues(alpha: 0.06)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: shouldHighlight
              ? highlightColor.withValues(alpha: 0.75)
              : AppColors.border,
          width: shouldHighlight ? 2 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            try {
              HapticFeedback.selectionClick();
            } catch (_) {}
            context.push('/delivery/orders/${order.id}');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.45,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metaLine,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusChipBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusChipFg,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              height: 1.1,
                              letterSpacing: 0.05,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            typeLabel,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              letterSpacing: 0.15,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                                  const Text(
                                    'Payment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: paymentColor.withValues(
                                        alpha: 0.32,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: paymentColor.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      paymentLabel,
                                      style: TextStyle(
                                        color: paymentChipFg,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                        height: 1.1,
                                        letterSpacing: 0.1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatRupee(order.totalAmount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.border.withValues(alpha: 0.65),
                          ),
                        ),
                        Text(
                          'LINE ITEMS',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: AppColors.textLight,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Builder(
                          builder: (context) {
                            const textStyle = TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.1,
                              height: 1.35,
                            );
                            final separatorStyle = textStyle.copyWith(
                              color: AppColors.textLight,
                            );

                            if (lineItemParts.isEmpty) {
                              return const Text(
                                emptyLineItemsText,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: textStyle,
                              );
                            }

                            final spans = <TextSpan>[];
                            for (int i = 0; i < lineItemParts.length; i++) {
                              if (i > 0) {
                                spans.add(
                                  TextSpan(text: ' | ', style: separatorStyle),
                                );
                              }
                              spans.add(TextSpan(text: lineItemParts[i]));
                            }

                            return Text.rich(
                              TextSpan(children: spans),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: textStyle,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({required bool hasAnyAssigned}) {
    return DeliveroEmptyState(
      title: hasAnyAssigned ? 'No matching orders' : 'No orders for you today',
      subtitle: hasAnyAssigned
          ? 'Try switching Active / Delivered or changing your search.'
          : 'Great job! You have no pending deliveries at the moment.',
      icon: Icons.local_shipping_outlined,
      actionLabel: hasAnyAssigned ? null : 'New order',
      onActionPressed: hasAnyAssigned
          ? null
          : () => context.push('/delivery/new-order'),
    );
  }
}

class _AssignedOrdersSearchSheet extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _AssignedOrdersSearchSheet({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Search orders',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: onChanged,
                  onSubmitted: (_) => Navigator.pop(context),
                  decoration: InputDecoration(
                    hintText: 'Order ID or customer…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: hasText
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: onClear,
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
