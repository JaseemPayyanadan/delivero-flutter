import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/food_item.dart';
import '../../../data/models/order.dart';
import '../../../data/models/delivery_route.dart';

class CreateOrderScreen extends ConsumerStatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  int _currentStep = 0;
  Customer? _selectedCustomer;
  OrderType _orderType = OrderType.daily;
  Map<String, int> _selectedItems = {}; // foodItemId -> quantity
  String _itemSearchQuery = '';
  bool _showSelectedOnly = false;

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final routes = ref.watch(routesProvider);
    final customersLoaded = ref.watch(customersLoadedProvider);
    final foodItemsLoaded = ref.watch(foodItemsLoadedProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const DeliveroSliverHeader(
            title: 'Initiate Order',
            expandedHeight: 120,
            floating: true,
            pinned: true,
          ),
          SliverToBoxAdapter(
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                ),
              ),
              child: Stepper(
                type: StepperType.vertical,
                currentStep: _currentStep,
                physics: const NeverScrollableScrollPhysics(),
                elevation: 0,
                onStepContinue: () {
                  if (_currentStep == 0 && _selectedCustomer == null) {
                    _showError('Please select an enterprise partner');
                    return;
                  }
                  if (_currentStep == 1 &&
                      _selectedItems.values.every((v) => v <= 0)) {
                    _showError('Please select at least one inventory unit');
                    return;
                  }
                  if (_currentStep < 2) {
                    setState(() => _currentStep += 1);
                  } else {
                    _submitOrder();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep -= 1);
                  } else {
                    context.pop();
                  }
                },
                controlsBuilder: (context, controls) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: controls.onStepContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _currentStep == 2
                                  ? 'AUTHORIZE ORDER'
                                  : 'CONTINUE',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: controls.onStepCancel,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              _currentStep == 0 ? 'ABORT' : 'BACK',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.textLight,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: const Text(
                      'ENTITY SELECTION',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    isActive: _currentStep >= 0,
                    state: _currentStep > 0
                        ? StepState.complete
                        : StepState.editing,
                    content: _buildCustomerStep(
                      customers,
                      routes,
                      customersLoaded: customersLoaded,
                      routesLoaded: routesLoaded,
                    ),
                  ),
                  Step(
                    title: const Text(
                      'INVENTORY MANIFEST',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    isActive: _currentStep >= 1,
                    state: _currentStep > 1
                        ? StepState.complete
                        : StepState.editing,
                    content: _buildItemsStep(
                      foodItems,
                      foodItemsLoaded: foodItemsLoaded,
                    ),
                  ),
                  Step(
                    title: const Text(
                      'FINAL REVIEW',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1,
                      ),
                    ),
                    isActive: _currentStep >= 2,
                    state: _currentStep > 2
                        ? StepState.complete
                        : StepState.editing,
                    content: _buildReviewStep(foodItems),
                  ),
                ],
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  String _customerSearchQuery = '';

  Widget _buildCustomerStep(
    List<Customer> customers,
    List<DeliveryRoute> routes, {
    required bool customersLoaded,
    required bool routesLoaded,
  }) {
    if (!customersLoaded && customers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final showRouteLoading = !routesLoaded && routes.isEmpty;

    final filteredCustomers = customers.where((c) {
      final matchesSearch =
          c.name.toLowerCase().contains(_customerSearchQuery.toLowerCase()) ||
          c.phone.contains(_customerSearchQuery);
      return matchesSearch;
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Enterprise Partner',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (val) => setState(() => _customerSearchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by name or phone...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textLight,
              ),
              filled: true,
              fillColor: AppColors.backgroundSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (filteredCustomers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No matching accounts found',
                  style: TextStyle(color: AppColors.textLight),
                ),
              ),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.builder(
                itemCount: filteredCustomers.length,
                itemBuilder: (context, index) {
                  final customer = filteredCustomers[index];
                  final isSelected = _selectedCustomer?.id == customer.id;
                  final route = routes.firstWhereOrNull(
                    (r) =>
                        r.id == customer.assignedRoute ||
                        r.name == customer.assignedRoute,
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLighter
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        setState(() {
                          _selectedCustomer = customer;
                          _selectedItems = {};
                          if (customer.products != null) {
                            for (var p in customer.products!) {
                              _selectedItems[p.id] = p.quantity;
                            }
                          }
                        });
                      },
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.backgroundSecondary,
                        child: Text(
                          customer.name.trim().isNotEmpty
                              ? customer.name.trim()[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.primary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      title: Text(
                        customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        '${showRouteLoading ? 'Loading route…' : (route?.name ?? 'No Route')} • ${customer.phone}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemsStep(
    List<FoodItem> foodItems, {
    required bool foodItemsLoaded,
  }) {
    if (!foodItemsLoaded && foodItems.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final query = _itemSearchQuery.trim().toLowerCase();
    final filteredItems = foodItems
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
    final selected =
        _selectedItems.entries
            .where((e) => e.value > 0)
            .map((e) {
              final item = foodItems.firstWhereOrNull((f) => f.id == e.key);
              return item == null ? null : (item, e.value);
            })
            .whereType<(FoodItem, int)>()
            .toList()
          ..sort((a, b) => a.$1.name.compareTo(b.$1.name));
    final selectedFiltered = query.isEmpty
        ? selected
        : selected
              .where((e) => e.$1.name.toLowerCase().contains(query))
              .toList();

    final showSelectedOnly = _showSelectedOnly && selected.isNotEmpty;
    final itemsToRender = showSelectedOnly
        ? selectedFiltered.map((e) => e.$1).toList()
        : filteredItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (val) => setState(() => _itemSearchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search catalog...',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textLight,
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('All items'),
                  selected: !_showSelectedOnly,
                  onSelected: (v) => setState(() => _showSelectedOnly = false),
                  showCheckmark: false,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ChoiceChip(
                  label: Text('Selected (${selected.length})'),
                  selected: _showSelectedOnly,
                  onSelected: (v) => setState(() => _showSelectedOnly = true),
                  showCheckmark: false,
                ),
              ),
            ],
          ),
        ],
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 16,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Selected Items',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    Text(
                      '${selected.length}',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: (selected.length * 64.0).clamp(64.0, 220.0),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: selected.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: AppColors.divider),
                    itemBuilder: (context, index) {
                      final (item, qty) = selected[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${NumberFormat.decimalPattern().format(item.price)} / unit',
                                    style: const TextStyle(
                                      color: AppColors.textLight,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildQtyBtn(
                                    Icons.remove_rounded,
                                    qty > 0
                                        ? () => setState(
                                            () => _selectedItems[item.id] =
                                                qty - 1,
                                          )
                                        : null,
                                  ),
                                  SizedBox(
                                    width: 32,
                                    child: Text(
                                      qty.toString(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  _buildQtyBtn(
                                    Icons.add_rounded,
                                    () => setState(
                                      () => _selectedItems[item.id] = qty + 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (itemsToRender.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                showSelectedOnly
                    ? 'No selected items yet'
                    : 'No catalog matches found',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 420,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: itemsToRender.length,
              itemBuilder: (context, index) {
                final item = itemsToRender[index];
                final qty = _selectedItems[item.id] ?? 0;
                final bool isSelected = qty > 0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '₹${NumberFormat.decimalPattern().format(item.price)} / unit',
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildQtyBtn(
                            Icons.remove_rounded,
                            qty > 0
                                ? () => setState(
                                    () => _selectedItems[item.id] = qty - 1,
                                  )
                                : null,
                          ),
                          SizedBox(
                            width: 32,
                            child: Text(
                              qty.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _buildQtyBtn(
                            Icons.add_rounded,
                            () => setState(
                              () => _selectedItems[item.id] = qty + 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback? onTap) {
    return IconButton(
      icon: Icon(icon, size: 18),
      onPressed: onTap,
      color: AppColors.primary,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildReviewStep(List<FoodItem> foodItems) {
    double subtotal = 0;
    final List<Map<String, dynamic>> orderItems = [];

    _selectedItems.forEach((id, qty) {
      if (qty > 0) {
        final item = foodItems.firstWhereOrNull((f) => f.id == id);
        if (item == null) return;
        final total = item.price * qty;
        subtotal += total;
        orderItems.add({'item': item, 'qty': qty, 'total': total});
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReviewRow(
                'ENTREPRISE PARTNER',
                _selectedCustomer?.name ?? 'UNSPECIFIED',
              ),
              _buildReviewRow(
                'LOGISTICS ROUTE',
                _selectedCustomer?.assignedRoute ?? 'PENDING ASSIGNMENT',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: AppColors.divider),
              ),
              if (orderItems.isEmpty)
                const Text(
                  'No items selected',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else
                SizedBox(
                  height: (orderItems.length * 42.0).clamp(84.0, 210.0),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: orderItems.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final oi = orderItems[index];
                      final FoodItem item = oi['item'];
                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLighter,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${oi['qty']}x',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '₹${NumberFormat.decimalPattern().format(oi['total'])}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: AppColors.divider),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'MANIFEST TOTAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textLight,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '₹${NumberFormat.decimalPattern().format(subtotal)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text(
          'CONTRACT TYPE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.textLight,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<OrderType>(
          initialValue: _orderType,
          items: OrderType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(
                    t.name.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (val) => setState(() => _orderType = val!),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.history_edu_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: AppColors.textLight,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _submitOrder() {
    final foodItems = ref.read(foodItemsProvider);
    final routes = ref.read(routesProvider);
    double subtotal = 0;
    final List<OrderItem> items = [];

    _selectedItems.forEach((id, qty) {
      if (qty > 0) {
        final foodItem = foodItems.firstWhereOrNull((f) => f.id == id);
        if (foodItem == null) return;
        final total = foodItem.price * qty;
        subtotal += total;
        items.add(
          OrderItem(
            id: const Uuid().v4(),
            foodItemId: id,
            foodItemName: foodItem.name,
            quantity: qty,
            unitPrice: foodItem.price,
            totalPrice: total,
          ),
        );
      }
    });

    final route = routes.firstWhereOrNull(
      (r) =>
          r.id == _selectedCustomer!.assignedRoute ||
          r.name == _selectedCustomer!.assignedRoute,
    );
    final assignedDriver = route?.assignedDriver;

    final newOrder = Order(
      id: const Uuid().v4(),
      factoryId: _selectedCustomer!.factoryId,
      orderType: _orderType,
      customerId: _selectedCustomer!.id,
      customerName: _selectedCustomer!.name,
      customerEmail: _selectedCustomer!.email,
      customerPhone: _selectedCustomer!.phone,
      customerAddress: _selectedCustomer!.address,
      items: items,
      subtotal: subtotal,
      discountAmount: 0.0,
      totalAmount: subtotal,
      status: OrderStatus.pending,
      assignedRoute: _selectedCustomer!.assignedRoute,
      assignedDriver: assignedDriver,
      orderDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    ref.read(ordersProvider.notifier).addOrder(newOrder);
    context.pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Manifest authorized successfully',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
