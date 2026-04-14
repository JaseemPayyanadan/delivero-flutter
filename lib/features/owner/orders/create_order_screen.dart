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
  final String? orderId;
  const CreateOrderScreen({super.key, this.orderId});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

enum _DeliveryScheduleMode { daily, weekly, custom }

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  Customer? _selectedCustomer;
  OrderType _orderType = OrderType.daily; // persisted model field
  _DeliveryScheduleMode _scheduleMode = _DeliveryScheduleMode.daily;
  final Set<int> _selectedWeekdays = {DateTime.monday};
  Map<String, int> _selectedItems = {}; // foodItemId -> quantity
  Map<String, double> _customUnitPrices = {}; // foodItemId -> unit price
  bool _isSubmitting = false;
  bool _initializedFromOrder = false;
  Order? _editingOrder;
  final Map<String, TextEditingController> _qtyControllers = {};

  void _removeQtyController(String id) {
    final c = _qtyControllers.remove(id);
    c?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final routes = ref.watch(routesProvider);
    final customersLoaded = ref.watch(customersLoadedProvider);
    final foodItemsLoaded = ref.watch(foodItemsLoadedProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    final hasSelectedUnits = _selectedItems.values.any((v) => v > 0);
    final selection = _computeSelectionSummary(foodItems);
    final discount = _computePartnerDiscount(selection.subtotal);
    final total = (selection.subtotal - discount)
        .clamp(0, double.infinity)
        .toDouble();

    final canSubmit =
        !_isSubmitting && _selectedCustomer != null && hasSelectedUnits;

    if (widget.orderId != null && !_initializedFromOrder) {
      final existing = ref
          .watch(ordersProvider)
          .firstWhereOrNull((o) => o.id == widget.orderId);
      if (existing != null) {
        final customer =
            customers.firstWhereOrNull((c) => c.id == existing.customerId);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _initializedFromOrder) return;
          setState(() {
            _editingOrder = existing;
            _selectedCustomer = customer;
            _orderType = existing.orderType;
            _selectedItems = {
              for (final i in existing.items) i.foodItemId: i.quantity,
            };
            _customUnitPrices = {
              for (final i in existing.items) i.foodItemId: i.unitPrice,
            };
            _initializedFromOrder = true;
          });
        });
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: widget.orderId == null ? 'Create Order' : 'Edit Order',
      ),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.orderId == null ? 'Create Order' : 'Edit Order',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: -1.0,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      widget.orderId == null
                          ? 'Configure your recurring delivery schedule'
                          : 'Update items, pricing and schedule',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel(label: 'Customer details'),
                    const SizedBox(height: 12),
                    _buildCustomerPicker(
                      customers,
                      routes,
                      customersLoaded: customersLoaded,
                      routesLoaded: routesLoaded,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Expanded(
                          child: _SectionLabel(label: 'Menu items'),
                        ),
                        TextButton.icon(
                          onPressed: foodItemsLoaded
                              ? () => _openItemsSheet(foodItems)
                              : null,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Add More',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildSelectedItemsList(foodItems),
                    const SizedBox(height: 18),
                    const _SectionLabel(label: 'Delivery schedule'),
                    const SizedBox(height: 12),
                    _buildSchedulePicker(),
                    const SizedBox(height: 18),
                    const _SectionLabel(label: 'Order summary'),
                    const SizedBox(height: 12),
                    _OrderSummaryCard(
                      subtotal: selection.subtotal,
                      discount: discount,
                      total: total,
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: FilledButton(
            onPressed: canSubmit ? _submitOrder : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.orderId == null
                        ? 'Confirm & Schedule Delivery'
                        : 'Update Order',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  String _customerSearchQuery = '';
  TextEditingController? _customerSearchController;
  TextEditingController? _itemSearchController;
  String _itemSearchQuery = '';

  @override
  void dispose() {
    _customerSearchController?.dispose();
    _itemSearchController?.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _computePartnerDiscount(double subtotal) {
    if (_selectedCustomer == null) return 0;
    if (subtotal <= 0) return 0;
    // Matches the sample UI (e.g. 600 -> 60). Keep simple for now.
    return subtotal * 0.10;
  }

  double _effectiveUnitPrice(FoodItem item) {
    return _customUnitPrices[item.id] ?? item.price;
  }

  void _showCustomPriceDialog(FoodItem item) {
    final messenger = ScaffoldMessenger.of(context);
    final current = _customUnitPrices[item.id];
    final controller = TextEditingController(
      text: current == null ? '' : current.toStringAsFixed(2),
    );
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Custom Price',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Default: ₹${NumberFormat.decimalPattern().format(item.price)}',
                  prefixIcon: const Icon(
                    Icons.currency_rupee_rounded,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (current != null)
              TextButton(
                onPressed: () {
                  setState(() => _customUnitPrices.remove(item.id));
                  Navigator.pop(context);
                },
                child: const Text(
                  'REMOVE',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text.trim().replaceAll(',', '');
                if (raw.isEmpty) {
                  setState(() => _customUnitPrices.remove(item.id));
                  Navigator.pop(context);
                  return;
                }
                final parsed = double.tryParse(raw);
                if (parsed == null || parsed <= 0) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Enter a valid price',
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
                setState(() => _customUnitPrices[item.id] = parsed);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    ).whenComplete(controller.dispose);
  }

  _SelectionSummary _computeSelectionSummary(List<FoodItem> foodItems) {
    if (_selectedItems.isEmpty) {
      return const _SelectionSummary(
        distinctItems: 0,
        totalUnits: 0,
        subtotal: 0,
      );
    }
    final byId = {for (final f in foodItems) f.id: f};
    var distinct = 0;
    var units = 0;
    var subtotal = 0.0;
    _selectedItems.forEach((id, qty) {
      if (qty <= 0) return;
      distinct += 1;
      units += qty;
      final item = byId[id];
      if (item == null) return;
      final unitPrice = _customUnitPrices[id] ?? item.price;
      subtotal += unitPrice * qty;
    });
    return _SelectionSummary(
      distinctItems: distinct,
      totalUnits: units,
      subtotal: subtotal,
    );
  }

  Widget _buildCustomerPicker(
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

    final selected = _selectedCustomer;

    return Column(
      children: [
        TextField(
          controller: _customerSearchController ??= TextEditingController(
            text: _customerSearchQuery,
          ),
          onChanged: (val) => setState(() => _customerSearchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search customer name or phone…',
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
        const SizedBox(height: 12),
        if (selected != null)
          _SelectedPartnerCard(
            customer: selected,
            routeName: routesLoaded
                ? routes
                          .firstWhereOrNull(
                            (r) =>
                                r.id == selected.assignedRoute ||
                                r.name == selected.assignedRoute,
                          )
                          ?.name ??
                      (selected.assignedRoute ?? 'Unassigned')
                : 'Loading route…',
            onChange: () => setState(() => _selectedCustomer = null),
          )
        else if (_customerSearchQuery.trim().isNotEmpty)
          _CustomerSuggestions(
            customers: filteredCustomers.take(6).toList(),
            showRouteLoading: showRouteLoading,
            routes: routes,
            onSelect: (customer) {
              setState(() {
                FocusScope.of(context).unfocus();
                _selectedCustomer = customer;
                _selectedItems = {};
                _customUnitPrices = {};
                _itemSearchQuery = '';
                _itemSearchController?.clear();
                if (customer.products != null) {
                  for (final p in customer.products!) {
                    _selectedItems[p.id] = p.quantity;
                  }
                }
              });
            },
          ),
      ],
    );
  }

  void _openItemsSheet(List<FoodItem> foodItems) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add items',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _itemSearchController ??= TextEditingController(
                      text: _itemSearchQuery,
                    ),
                    onChanged: (val) => setState(() => _itemSearchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search catalog',
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
                  const SizedBox(height: 14),
                  Expanded(
                    child: _CatalogList(
                      controller: controller,
                      items: _filterCatalog(foodItems),
                      getQty: (id) => _selectedItems[id] ?? 0,
                      getUnitPrice: _effectiveUnitPrice,
                      isCustom: (id) => _customUnitPrices.containsKey(id),
                      onCustomPrice: _showCustomPriceDialog,
                      onInc: (id) => setState(
                        () =>
                            _selectedItems[id] = (_selectedItems[id] ?? 0) + 1,
                      ),
                      onDec: (id) {
                        final qty = _selectedItems[id] ?? 0;
                        if (qty <= 0) return;
                        setState(() {
                          final next = qty - 1;
                          if (next <= 0) {
                            _selectedItems.remove(id);
                            _customUnitPrices.remove(id);
                          } else {
                            _selectedItems[id] = next;
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<FoodItem> _filterCatalog(List<FoodItem> foodItems) {
    final q = _itemSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return foodItems;
    return foodItems.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  Widget _buildSelectedItemsList(List<FoodItem> foodItems) {
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

    if (selected.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'Add items to continue',
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final selectedIds = selected.map((e) => e.$1.id).toSet();
    final staleIds = _qtyControllers.keys.where((k) => !selectedIds.contains(k));
    for (final id in staleIds.toList()) {
      _removeQtyController(id);
    }

    return Column(
      children: [
        for (final (item, qty) in selected) ...[
          () {
            final controller = _qtyControllers.putIfAbsent(
              item.id,
              () => TextEditingController(text: qty.toString()),
            );
            if (controller.text != qty.toString()) {
              controller.text = qty.toString();
              controller.selection = TextSelection.fromPosition(
                TextPosition(offset: controller.text.length),
              );
            }
            return _SelectedMenuItemCard(
              name: item.name,
              unitPrice: _effectiveUnitPrice(item),
              isCustom: _customUnitPrices.containsKey(item.id),
              qty: qty,
              qtyController: controller,
              onQtyChanged: (nextQty) => setState(() {
                final safe = nextQty.clamp(0, 999);
                if (safe <= 0) {
                  _selectedItems.remove(item.id);
                  _customUnitPrices.remove(item.id);
                  _removeQtyController(item.id);
                } else {
                  _selectedItems[item.id] = safe;
                }
              }),
              onCustomPrice: () => _showCustomPriceDialog(item),
              onDec: () {
                if (qty <= 0) return;
                setState(() {
                  final next = qty - 1;
                  if (next <= 0) {
                    _selectedItems.remove(item.id);
                    _customUnitPrices.remove(item.id);
                    _removeQtyController(item.id);
                  } else {
                    _selectedItems[item.id] = next;
                  }
                });
              },
              onInc: () => setState(() => _selectedItems[item.id] = qty + 1),
            );
          }(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildSchedulePicker() {
    Widget pill(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? Colors.transparent : AppColors.border,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final showWeekdays = _scheduleMode != _DeliveryScheduleMode.daily;

    return Column(
      children: [
        Row(
          children: [
            pill(
              'Daily',
              _scheduleMode == _DeliveryScheduleMode.daily,
              () => setState(() {
                _scheduleMode = _DeliveryScheduleMode.daily;
                _orderType = OrderType.daily;
              }),
            ),
            const SizedBox(width: 10),
            pill(
              'Weekly',
              _scheduleMode == _DeliveryScheduleMode.weekly,
              () => setState(() {
                _scheduleMode = _DeliveryScheduleMode.weekly;
                _orderType = OrderType.daily;
              }),
            ),
            const SizedBox(width: 10),
            pill(
              'Custom',
              _scheduleMode == _DeliveryScheduleMode.custom,
              () => setState(() {
                _scheduleMode = _DeliveryScheduleMode.custom;
                _orderType = OrderType.daily;
              }),
            ),
          ],
        ),
        if (showWeekdays) ...[
          const SizedBox(height: 14),
          _WeekdayPicker(
            selected: _selectedWeekdays,
            onToggle: (day) => setState(() {
              if (_selectedWeekdays.contains(day)) {
                if (_selectedWeekdays.length > 1) _selectedWeekdays.remove(day);
              } else {
                _selectedWeekdays.add(day);
              }
            }),
          ),
        ],
      ],
    );
  }

  void _submitOrder() {
    if (_isSubmitting) return;
    if (_selectedCustomer == null) return;
    if (_selectedItems.values.every((v) => v <= 0)) return;
    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();
    final foodItems = ref.read(foodItemsProvider);
    final routes = ref.read(routesProvider);
    double subtotal = 0;
    final List<OrderItem> items = [];

    _selectedItems.forEach((id, qty) {
      if (qty > 0) {
        final foodItem = foodItems.firstWhereOrNull((f) => f.id == id);
        if (foodItem == null) return;
        final unitPrice = _customUnitPrices[id] ?? foodItem.price;
        final total = unitPrice * qty;
        subtotal += total;
        items.add(
          OrderItem(
            id: const Uuid().v4(),
            foodItemId: id,
            foodItemName: foodItem.name,
            quantity: qty,
            unitPrice: unitPrice,
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
    final discountAmount = _computePartnerDiscount(subtotal);
    final totalAmount = (subtotal - discountAmount)
        .clamp(0, double.infinity)
        .toDouble();

    final now = DateTime.now();
    final existing = _editingOrder;
    final nextOrder = existing == null
        ? Order(
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
            discountAmount: discountAmount,
            totalAmount: totalAmount,
            status: OrderStatus.pending,
            assignedRoute: _selectedCustomer!.assignedRoute,
            assignedDriver: assignedDriver,
            orderDate: now,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            factoryId: _selectedCustomer!.factoryId,
            orderType: _orderType,
            customerId: _selectedCustomer!.id,
            customerName: _selectedCustomer!.name,
            customerEmail: _selectedCustomer!.email,
            customerPhone: _selectedCustomer!.phone,
            customerAddress: _selectedCustomer!.address,
            items: items,
            subtotal: subtotal,
            discountAmount: discountAmount,
            totalAmount: totalAmount,
            assignedRoute: _selectedCustomer!.assignedRoute,
            assignedDriver: assignedDriver,
            updatedAt: now,
          );

    if (existing == null) {
      ref.read(ordersProvider.notifier).addOrder(nextOrder);
    } else {
      ref.read(ordersProvider.notifier).updateOrder(nextOrder);
    }
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existing == null ? 'Order created successfully' : 'Order updated',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    context.pop();
  }
}

class _SelectionSummary {
  final int distinctItems;
  final int totalUnits;
  final double subtotal;

  const _SelectionSummary({
    required this.distinctItems,
    required this.totalUnits,
    required this.subtotal,
  });
}

class _SelectedPartnerCard extends StatelessWidget {
  final Customer customer;
  final String routeName;
  final VoidCallback onChange;

  const _SelectedPartnerCard({
    required this.customer,
    required this.routeName,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
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
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$routeName • ${customer.phone}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 10,
        color: AppColors.textLight,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _CustomerSuggestions extends StatelessWidget {
  final List<Customer> customers;
  final bool showRouteLoading;
  final List<DeliveryRoute> routes;
  final ValueChanged<Customer> onSelect;

  const _CustomerSuggestions({
    required this.customers,
    required this.showRouteLoading,
    required this.routes,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text(
          'No matching customers',
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < customers.length; i++) ...[
            ListTile(
              dense: true,
              onTap: () => onSelect(customers[i]),
              leading: const CircleAvatar(
                backgroundColor: AppColors.backgroundSecondary,
                child: Icon(Icons.person_rounded, color: AppColors.primary),
              ),
              title: Text(
                customers[i].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              subtitle: Text(
                '${showRouteLoading ? 'Loading route…' : (routes.firstWhereOrNull((r) => r.id == customers[i].assignedRoute || r.name == customers[i].assignedRoute)?.name ?? 'No Route')} • ${customers[i].phone}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (i != customers.length - 1)
              const Divider(height: 1, color: AppColors.divider),
          ],
        ],
      ),
    );
  }
}

class _SelectedMenuItemCard extends StatelessWidget {
  final String name;
  final double unitPrice;
  final bool isCustom;
  final int qty;
  final TextEditingController qtyController;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onCustomPrice;
  final VoidCallback onDec;
  final VoidCallback onInc;

  const _SelectedMenuItemCard({
    required this.name,
    required this.unitPrice,
    required this.isCustom,
    required this.qty,
    required this.qtyController,
    required this.onQtyChanged,
    required this.onCustomPrice,
    required this.onDec,
    required this.onInc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₹${NumberFormat.decimalPattern().format(unitPrice)}.00',
                      style: TextStyle(
                        color: isCustom ? AppColors.primary : AppColors.textLight,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                      ),
                    ),
                    if (isCustom) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onCustomPrice,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLighter.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Custom',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onCustomPrice,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Add custom',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _QtyStepper(
            qty: qty,
            controller: qtyController,
            onQtyChanged: onQtyChanged,
            onDec: onDec,
            onInc: onInc,
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final TextEditingController? controller;
  final ValueChanged<int>? onQtyChanged;
  final VoidCallback onDec;
  final VoidCallback onInc;
  const _QtyStepper({
    required this.qty,
    this.controller,
    this.onQtyChanged,
    required this.onDec,
    required this.onInc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: qty > 0 ? onDec : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
            color: AppColors.textPrimary,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
          ),
          SizedBox(
            width: 42,
            child: controller == null || onQtyChanged == null
                ? Center(
                    child: Text(
                      qty.toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  )
                : TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                    onEditingComplete: () {
                      final raw = controller!.text.trim();
                      if (raw.isEmpty) {
                        onQtyChanged!(0);
                      }
                      FocusScope.of(context).unfocus();
                    },
                    onChanged: (val) {
                      final raw = val.trim();
                      if (raw.isEmpty) return;
                      final parsed = int.tryParse(raw);
                      if (parsed == null) return;
                      onQtyChanged!(parsed);
                    },
                  ),
          ),
          IconButton(
            onPressed: onInc,
            icon: const Icon(Icons.add_rounded, size: 18),
            color: AppColors.textPrimary,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  const _WeekdayPicker({required this.selected, required this.onToggle});

  static const _days = <int, String>{
    DateTime.monday: 'M',
    DateTime.tuesday: 'T',
    DateTime.wednesday: 'W',
    DateTime.thursday: 'T',
    DateTime.friday: 'F',
    DateTime.saturday: 'S',
    DateTime.sunday: 'S',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _days.entries.map((e) {
        final isSelected = selected.contains(e.key);
        return InkWell(
          onTap: () => onToggle(e.key),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.border,
              ),
            ),
            child: Center(
              child: Text(
                e.value,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textLight,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OrderSummaryCard extends StatelessWidget {
  final double subtotal;
  final double discount;
  final double total;

  const _OrderSummaryCard({
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryLighter.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _summaryRow(
            'Subtotal',
            '₹${NumberFormat.decimalPattern().format(subtotal)}.00',
          ),
          const SizedBox(height: 10),
          _summaryRow(
            'Partner Discount',
            '- ₹${NumberFormat.decimalPattern().format(discount)}.00',
            valueColor: AppColors.success,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Amount',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                '₹${NumberFormat.decimalPattern().format(total)}.00',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color valueColor = AppColors.textPrimary,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _CatalogList extends StatelessWidget {
  final ScrollController controller;
  final List<FoodItem> items;
  final int Function(String id) getQty;
  final double Function(FoodItem item) getUnitPrice;
  final bool Function(String id) isCustom;
  final void Function(FoodItem item) onCustomPrice;
  final void Function(String id) onInc;
  final void Function(String id) onDec;

  const _CatalogList({
    required this.controller,
    required this.items,
    required this.getQty,
    required this.getUnitPrice,
    required this.isCustom,
    required this.onCustomPrice,
    required this.onInc,
    required this.onDec,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'No catalog matches found',
          style: TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final qty = getQty(item.id);
        final unitPrice = getUnitPrice(item);
        final custom = isCustom(item.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
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
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '₹${NumberFormat.decimalPattern().format(unitPrice)} / unit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => onCustomPrice(item),
                          style: TextButton.styleFrom(
                            foregroundColor: custom
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            custom ? 'Custom' : 'Add custom',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _QtyStepper(
                qty: qty,
                onDec: () => onDec(item.id),
                onInc: () => onInc(item.id),
              ),
            ],
          ),
        );
      },
    );
  }
}
