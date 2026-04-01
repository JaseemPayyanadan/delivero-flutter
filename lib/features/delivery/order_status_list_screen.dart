import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final allOrders = ref.watch(ordersProvider);

    // Filter orders for the current driver
    final driverId = user?.linkedEntityId ?? user?.id;
    var myOrders = allOrders
        .where((o) => o.assignedDriver == driverId)
        .toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      myOrders = myOrders.where((o) {
        return o.customerName.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            o.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            o.customerAddress.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
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

    myOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const DeliveroSliverHeader(
            title: 'Assigned Orders',
            expandedHeight: 120,
          ),
          SliverToBoxAdapter(
            child: _buildFilters(
              allOrders.where((o) => o.assignedDriver == driverId).toList(),
            ),
          ),
          if (myOrders.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  Widget _buildFilters(List<Order> myAllOrders) {
    final activeCount = myAllOrders
        .where((o) => o.status != OrderStatus.delivered)
        .length;
    final deliveredCount = myAllOrders
        .where((o) => o.status == OrderStatus.delivered)
        .length;

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search orders...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildFilterChip('all', 'Active ($activeCount)'),
              const SizedBox(width: 8),
              _buildFilterChip('delivered', 'Delivered ($deliveredCount)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedStatus == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) => setState(() => _selectedStatus = key),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, Order order) {
    final timeStr = DateFormat('hh:mm a').format(order.orderDate);
    final isDelivered = order.status == OrderStatus.delivered;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order.customerName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              order.customerAddress,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '₹${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (!isDelivered)
                  FilledButton.icon(
                    onPressed: () => _confirmDelivery(context, ref, order),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Deliver'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'DELIVERED',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 64,
            color: AppColors.textLight,
          ),
          SizedBox(height: 16),
          Text(
            'No orders for you today',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
