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
  Map<String, double> _customUnitPrices = {}; // foodItemId -> unit price
  String _itemSearchQuery = '';
  bool _showSelectedOnly = false;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final routes = ref.watch(routesProvider);
    final customersLoaded = ref.watch(customersLoadedProvider);
    final foodItemsLoaded = ref.watch(foodItemsLoadedProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    final selection = _computeSelectionSummary(foodItems);
    final hasSelectedUnits = _selectedItems.values.any((v) => v > 0);

    final canContinue = switch (_currentStep) {
      0 => _selectedCustomer != null,
      1 => hasSelectedUnits,
      _ => _selectedCustomer != null && hasSelectedUnits,
    };
    final helperText = canContinue
        ? null
        : (_currentStep == 0
              ? 'Select a partner to continue'
              : 'Add at least 1 unit to continue');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const DeliveroAppBar(title: 'Initiate Order'),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: _buildStepHeader(),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: _currentStep == 0
                  ? _buildCustomerStep(
                      customers,
                      routes,
                      customersLoaded: customersLoaded,
                      routesLoaded: routesLoaded,
                    )
                  : _currentStep == 1
                  ? _buildItemsStep(
                      foodItems,
                      foodItemsLoaded: foodItemsLoaded,
                      routes: routes,
                      routesLoaded: routesLoaded,
                    )
                  : _buildReviewStep(foodItems, routes),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedCustomer?.name ?? 'Partner not selected',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    selection.totalUnits == 0
                        ? 'No items'
                        : '${selection.distinctItems} items • ${selection.totalUnits} units • ₹${NumberFormat.compact().format(selection.subtotal)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (helperText != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    helperText,
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : _currentStep == 0
                          ? () => context.pop()
                          : () => setState(() => _currentStep -= 1),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentStep == 0 ? 'Cancel' : 'Back',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: (_isSubmitting || !canContinue)
                          ? null
                          : () {
                              if (_currentStep < 2) {
                                FocusScope.of(context).unfocus();
                                setState(() => _currentStep += 1);
                              } else {
                                _submitOrder();
                              }
                            },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isSubmitting && _currentStep == 2
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _currentStep == 2
                                  ? 'Authorize Order'
                                  : 'Continue',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _customerSearchQuery = '';
  TextEditingController? _customerSearchController;
  TextEditingController? _itemSearchController;

  @override
  void dispose() {
    _customerSearchController?.dispose();
    _itemSearchController?.dispose();
    super.dispose();
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

  Widget _buildStepHeader() {
    final steps = const ['Partner', 'Items', 'Review'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: InkWell(
                onTap: i <= _currentStep
                    ? () => setState(() => _currentStep = i)
                    : null,
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StepDot(
                      state: i < _currentStep
                          ? _StepDotState.complete
                          : i == _currentStep
                          ? _StepDotState.active
                          : _StepDotState.inactive,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      steps[i],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: i == _currentStep
                            ? AppColors.textPrimary
                            : AppColors.textLight,
                        fontWeight: i == _currentStep
                            ? FontWeight.w900
                            : FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (i != steps.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: i < _currentStep
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select partner',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _customerSearchController ??= TextEditingController(
            text: _customerSearchQuery,
          ),
          onChanged: (val) => setState(() => _customerSearchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search by name or phone',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textLight,
            ),
            suffixIcon: _customerSearchQuery.trim().isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _customerSearchController?.clear();
                      setState(() => _customerSearchQuery = '');
                    },
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
            height: MediaQuery.of(context).size.height * 0.42,
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

                return Column(
                  children: [
                    ListTile(
                      onTap: () {
                        setState(() {
                          FocusScope.of(context).unfocus();
                          _selectedCustomer = customer;
                          _selectedItems = {};
                          _customUnitPrices = {};
                          _itemSearchQuery = '';
                          _itemSearchController?.clear();
                          _showSelectedOnly = false;
                          if (customer.products != null) {
                            for (var p in customer.products!) {
                              _selectedItems[p.id] = p.quantity;
                            }
                          }
                          _currentStep = 1;
                        });
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? AppColors.primary
                            : AppColors.backgroundSecondary,
                        child: Icon(
                          Icons.storefront_outlined,
                          color: isSelected ? Colors.white : AppColors.primary,
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
                    if (index != filteredCustomers.length - 1)
                      const Divider(height: 1, color: AppColors.divider),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildItemsStep(
    List<FoodItem> foodItems, {
    required bool foodItemsLoaded,
    required List<DeliveryRoute> routes,
    required bool routesLoaded,
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
        if (_selectedCustomer != null) ...[
          _SelectedPartnerCard(
            customer: _selectedCustomer!,
            routeName: routesLoaded
                ? routes
                          .firstWhereOrNull(
                            (r) =>
                                r.id == _selectedCustomer!.assignedRoute ||
                                r.name == _selectedCustomer!.assignedRoute,
                          )
                          ?.name ??
                      (_selectedCustomer!.assignedRoute ?? 'Unassigned')
                : 'Loading route…',
            onChange: () => setState(() => _currentStep = 0),
          ),
          const SizedBox(height: 14),
        ],
        const Text(
          'Build manifest',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 14),
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
            suffixIcon: _itemSearchQuery.trim().isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _itemSearchController?.clear();
                      setState(() => _itemSearchQuery = '');
                    },
                  ),
            filled: true,
            fillColor: AppColors.backgroundSecondary,
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
                  label: const Text('All'),
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
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${selected.length} selected',
                  style: const TextStyle(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _selectedItems = {};
                  _customUnitPrices = {};
                  _showSelectedOnly = false;
                }),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Clear',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
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
            height: MediaQuery.of(context).size.height * 0.52,
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: itemsToRender.length,
              itemBuilder: (context, index) {
                final item = itemsToRender[index];
                final qty = _selectedItems[item.id] ?? 0;
                final bool isSelected = qty > 0;
                final isCustom = _customUnitPrices.containsKey(item.id);
                final unitPrice = _effectiveUnitPrice(item);
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
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '₹${NumberFormat.decimalPattern().format(unitPrice)} / unit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => _showCustomPriceDialog(item),
                          style: TextButton.styleFrom(
                            foregroundColor: isCustom
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isCustom ? 'Custom' : 'Add custom',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
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
                                ? () => setState(() {
                                    final next = qty - 1;
                                    if (next <= 0) {
                                      _selectedItems.remove(item.id);
                                      _customUnitPrices.remove(item.id);
                                      if (_showSelectedOnly &&
                                          _selectedItems.values.every(
                                            (v) => v <= 0,
                                          )) {
                                        _showSelectedOnly = false;
                                      }
                                    } else {
                                      _selectedItems[item.id] = next;
                                    }
                                  })
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

  Widget _buildReviewStep(
    List<FoodItem> foodItems,
    List<DeliveryRoute> routes,
  ) {
    double subtotal = 0;
    final List<Map<String, dynamic>> orderItems = [];

    _selectedItems.forEach((id, qty) {
      if (qty > 0) {
        final item = foodItems.firstWhereOrNull((f) => f.id == id);
        if (item == null) return;
        final unitPrice = _customUnitPrices[id] ?? item.price;
        final total = unitPrice * qty;
        subtotal += total;
        orderItems.add({
          'item': item,
          'qty': qty,
          'total': total,
          'unitPrice': unitPrice,
        });
      }
    });

    final route = _selectedCustomer == null
        ? null
        : routes.firstWhereOrNull(
            (r) =>
                r.id == _selectedCustomer!.assignedRoute ||
                r.name == _selectedCustomer!.assignedRoute,
          );

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
                'Partner',
                _selectedCustomer?.name ?? 'Unspecified',
              ),
              _buildReviewRow(
                'Route',
                route?.name ??
                    (_selectedCustomer?.assignedRoute ?? 'Pending assignment'),
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
                      final unitPrice = (oi['unitPrice'] as num).toDouble();
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
                              '${item.name} • ₹${NumberFormat.decimalPattern().format(unitPrice)}',
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
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Order type',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Daily'),
                      selected: _orderType == OrderType.daily,
                      onSelected: (_) =>
                          setState(() => _orderType = OrderType.daily),
                      showCheckmark: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('One-time'),
                      selected: _orderType == OrderType.oneTime,
                      onSelected: (_) =>
                          setState(() => _orderType = OrderType.oneTime),
                      showCheckmark: false,
                    ),
                  ),
                ],
              ),
            ],
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

enum _StepDotState { inactive, active, complete }

class _StepDot extends StatelessWidget {
  final _StepDotState state;

  const _StepDot({required this.state});

  @override
  Widget build(BuildContext context) {
    final isActive = state == _StepDotState.active;
    final isComplete = state == _StepDotState.complete;
    final bg = isComplete ? AppColors.primary : Colors.transparent;
    final border = isComplete
        ? AppColors.primary
        : isActive
        ? AppColors.primary
        : AppColors.border;

    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1.6),
      ),
      child: Center(
        child: isComplete
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
      ),
    );
  }
}
