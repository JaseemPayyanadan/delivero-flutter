import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/maps_launch.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../data/models/order.dart';

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

    // Filter orders for the current driver
    final driverId = user?.linkedEntityId ?? user?.id;
    var myOrders = allOrders
        .where((o) => o.assignedDriver == driverId)
        .toList();

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
      myOrders = myOrders
          .where((o) => o.status != OrderStatus.delivered)
          .toList();
    } else if (_selectedStatus == 'delivered') {
      myOrders = myOrders
          .where((o) => o.status == OrderStatus.delivered)
          .toList();
    }

    myOrders.sort((a, b) {
      final statusPriority = {
        OrderStatus.pending: 1,
        OrderStatus.confirmed: 2,
        OrderStatus.preparing: 3,
        OrderStatus.ready: 4,
        OrderStatus.cancelled: 5,
        OrderStatus.delivered: 6,
      };
      final aP = statusPriority[a.status] ?? 7;
      final bP = statusPriority[b.status] ?? 7;
      if (aP != bP) return aP.compareTo(bP);
      return b.orderDate.compareTo(a.orderDate);
    });

    final myAllOrders =
        allOrders.where((o) => o.assignedDriver == driverId).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Assigned Orders',
        leading: null,
        actions: [
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
    final activeCount =
        myAllOrders.where((o) => o.status != OrderStatus.delivered).length;
    final deliveredCount =
        myAllOrders.where((o) => o.status == OrderStatus.delivered).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildStatusPill(
              'all',
              'Active ($activeCount)',
            ),
            _buildStatusPill(
              'delivered',
              'Delivered ($deliveredCount)',
            ),
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

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, Order order) {
    final isDelivered = order.status == OrderStatus.delivered;
    final customerName = order.customerName.trim().isEmpty
        ? 'Unknown'
        : order.customerName.trim();
    final displayId = _displayOrderId(order.id);
    final typeLabel = order.orderType == OrderType.daily
        ? 'Daily order'
        : 'One-time order';

    final statusText = _humanStatus(order.status);
    final statusColor = _getStatusColor(order.status);
    final statusChipBg = switch (order.status) {
      OrderStatus.pending => const Color(0xFF6D5EF6),
      _ => statusColor,
    };
    const statusChipFg = Colors.white;

    final details = order.items
        .take(4)
        .map((i) {
          final price = i.totalPrice;
          final priceLabel = price == price.roundToDouble()
              ? price.toStringAsFixed(0)
              : price.toStringAsFixed(2);
          return '${i.foodItemName} ($priceLabel)';
        })
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            try {
              HapticFeedback.selectionClick();
            } catch (_) {}
            context.push('/delivery/orders/${order.id}');
          },
          child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.45,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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
                    style: const TextStyle(
                      color: statusChipFg,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer Name:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total Amount',
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
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 18),
            const Text(
              'Order Details',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              details.isEmpty ? '—' : details,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.textPrimary,
                letterSpacing: -0.15,
                height: 1.25,
              ),
            ),
            if (order.customerAddress.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openMaps(context, order.customerAddress),
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: const Text('Navigate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!isDelivered)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _confirmDelivery(context, ref, order),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Deliver'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.20),
                  ),
                ),
                child: const Center(
                  child: Text(
                    'DELIVERED',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Future<void> _openMaps(BuildContext context, String address) async {
    final ok = await openMapsForAddress(address);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
    }
  }

  void _confirmDelivery(BuildContext context, WidgetRef ref, Order order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delivery'),
        content: Text(
          'Are you sure you want to mark order for ${order.customerName} as delivered?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final updatedOrder = order.copyWith(
                status: OrderStatus.delivered,
              );
              ref.read(ordersProvider.notifier).updateOrder(updatedOrder);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Order marked as delivered')),
              );
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirm'),
          ),
        ],
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
