import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../../../../app/providers.dart';
import '../../../../app/order_settings_provider.dart';
import '../../../../core/orders/business_day.dart';
import '../../../../core/orders/order_merge.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/delivero_sliver_header.dart';
import '../../../../core/utils/route_refs.dart';
import '../../../../data/models/customer.dart';
import '../../../../data/models/food_item.dart';
import '../../../../data/models/order.dart';
import '../../../../data/models/delivery_route.dart';

part 'create_order_widgets.dart';

String _formatRupee(double amount) {
  final whole = amount == amount.roundToDouble();
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: whole ? 0 : 2,
  ).format(amount);
}

class CreateOrderScreen extends ConsumerStatefulWidget {
  final String? orderId;
  final bool forDriver;

  const CreateOrderScreen({super.key, this.orderId, this.forDriver = false});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  static const int _stepCount = 4;
  static const List<String> _stepTitles = [
    'Customer',
    'Schedule',
    'Menu items',
    'Order details',
  ];

  Customer? _selectedCustomer;
  DeliveryRun _deliveryRun = DeliveryRun.morning;
  OrderType? _orderType;
  Map<String, int> _selectedItems = {}; // foodItemId -> quantity
  Map<String, double> _customUnitPrices = {}; // foodItemId -> unit price
  bool _isSubmitting = false;
  bool _createSeparateOrder = false;
  bool _initializedFromOrder = false;
  Order? _editingOrder;
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, TextEditingController> _catalogQtyControllers = {};

  /// 0 = customer, 1 = order type, 2 = menu, 3 = review.
  int _step = 0;

  void _removeQtyController(String id) {
    final c = _qtyControllers.remove(id);
    c?.dispose();
  }

  void _removeCatalogQtyController(String id) {
    final c = _catalogQtyControllers.remove(id);
    c?.dispose();
  }

  TextEditingController _catalogQtyControllerFor(String id) {
    return _catalogQtyControllers.putIfAbsent(
      id,
      () => TextEditingController(text: (_selectedItems[id] ?? 0).toString()),
    );
  }

  void _disposeCatalogQtyControllers() {
    for (final c in _catalogQtyControllers.values) {
      c.dispose();
    }
    _catalogQtyControllers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final customers = ref.watch(customersProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final routes = ref.watch(routesProvider);
    final drivers = ref.watch(driversProvider);
    final customersLoaded = ref.watch(customersLoadedProvider);
    final foodItemsLoaded = ref.watch(foodItemsLoadedProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    final driverId = widget.forDriver
        ? (user?.linkedEntityId ?? user?.id)
        : null;
    final currentDriver = widget.forDriver
        ? drivers.firstWhereOrNull((d) => d.id == driverId)
        : null;
    final driverRouteId = currentDriver?.currentRoute?.trim();
    final visibleCustomers = widget.forDriver
        ? customers
              .where(
                (customer) => _customerMatchesRoute(
                  customer,
                  driverRouteId: driverRouteId,
                  routes: routes,
                ),
              )
              .toList()
        : customers;
    final hasSelectedUnits = _selectedItems.values.any((v) => v > 0);
    final selection = _computeSelectionSummary(foodItems);
    final canPrimaryProceed =
        !_isSubmitting &&
        _canGoNextFromStep(hasSelectedUnits: hasSelectedUnits);
    final total = selection.subtotal.clamp(0, double.infinity).toDouble();

    if (widget.orderId != null && !_initializedFromOrder) {
      final existing = ref
          .watch(ordersProvider)
          .firstWhereOrNull((o) => o.id == widget.orderId);
      if (existing != null) {
        final customer = customers.firstWhereOrNull(
          (c) => c.id == existing.customerId,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _initializedFromOrder) return;
          setState(() {
            _editingOrder = existing;
            _selectedCustomer = customer;
            _orderType = existing.orderType;
            _deliveryRun = existing.deliveryRun;
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

    final stepSubtitle = switch (_step) {
      0 =>
        widget.orderId == null
            ? 'Step 1 of 4 — Search and choose who this order is for.'
            : 'Step 1 of 4 — Customer for this order.',
      1 => 'Step 2 of 4 — Delivery run and order type.',
      2 => 'Step 3 of 4 — Add products and set quantities.',
      _ => 'Step 4 of 4 — Check everything before you save.',
    };

    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _step -= 1);
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: DeliveroAppBar(
          title: widget.orderId == null
              ? (widget.forDriver ? 'New order' : 'Create order')
              : 'Edit order',
          leading: (Navigator.of(context).canPop() || _step > 0)
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () {
                    if (_step > 0) {
                      setState(() => _step -= 1);
                    } else if (Navigator.of(context).canPop()) {
                      context.pop();
                    }
                  },
                )
              : null,
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _CreateOrderStepProgress(
                  stepIndex: _step,
                  stepCount: _stepCount,
                  labels: _stepTitles,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _stepTitles[_step],
                        style: context.appTextStyles.appBarTitle,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        stepSubtitle,
                        style: context.appTextStyles.sliverSubtitle,
                      ),
                      const SizedBox(height: 20),
                      switch (_step) {
                        0 => _buildCustomerPicker(
                          visibleCustomers,
                          routes,
                          customersLoaded: customersLoaded,
                          routesLoaded: routesLoaded,
                          driverRouteId: driverRouteId,
                        ),
                        1 => _FormSectionCard(
                          title: 'Schedule',
                          child: _buildSchedulePicker(),
                        ),
                        2 => _FormSectionCard(
                          title: 'Menu items',
                          subtitle: !foodItemsLoaded && foodItems.isEmpty
                              ? 'Loading your catalog…'
                              : null,
                          trailing: TextButton.icon(
                            onPressed: foodItemsLoaded
                                ? () => _openItemsSheet(foodItems)
                                : null,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 18,
                            ),
                            label: Text(
                              'Add items',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.appTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          child: _buildSelectedItemsList(
                            foodItems,
                            catalogLoaded: foodItemsLoaded,
                            onBrowseCatalog: foodItemsLoaded
                                ? () => _openItemsSheet(foodItems)
                                : null,
                          ),
                        ),
                        _ => _buildReviewStep(
                          foodItems: foodItems,
                          selection: selection,
                          orderTotal: total,
                        ),
                      },
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: const Border(top: BorderSide(color: AppColors.border)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    _primaryBarLeftCaption(
                      hasSelectedUnits: hasSelectedUnits,
                      selection: selection,
                      total: total,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.start,
                    style: context.appTextStyles.caption.copyWith(
                      color: canPrimaryProceed
                          ? AppColors.textSecondary
                          : AppColors.textLight,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: !canPrimaryProceed
                      ? null
                      : () => _onPrimaryStepAction(
                          hasSelectedUnits: hasSelectedUnits,
                        ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.backgroundSecondary,
                    disabledForegroundColor: AppColors.textLight,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Theme.of(context).colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          _step < 3
                              ? 'Continue'
                              : (widget.orderId == null ? 'Confirm' : 'Update'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.appTextStyles.buttonLabel.copyWith(
                            color: Theme.of(context).colorScheme.onPrimary,
                            letterSpacing: 0.2,
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

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }

  bool _customerMatchesRoute(
    Customer customer, {
    required String? driverRouteId,
    required List<DeliveryRoute> routes,
  }) {
    final normalizedDriverRouteId = driverRouteId?.trim();
    if (normalizedDriverRouteId == null || normalizedDriverRouteId.isEmpty) {
      return false;
    }

    final customerRouteId = RouteRefs.routeIdForRef(
      customer.assignedRoute,
      routes,
    );
    return customerRouteId != null &&
        customerRouteId == normalizedDriverRouteId;
  }

  String _routeLabelForCustomer(
    Customer customer,
    List<DeliveryRoute> routes, {
    required bool routesLoaded,
  }) {
    return RouteRefs.routeLabelForRef(
      customer.assignedRoute,
      routes,
      routesLoaded: routesLoaded,
    );
  }

  int _customerMatchScore(
    Customer customer,
    String query,
    String queryDigits,
    List<DeliveryRoute> routes, {
    required bool routesLoaded,
  }) {
    if (query.isEmpty && queryDigits.isEmpty) return 100;

    final name = customer.name.trim().toLowerCase();
    final owner = (customer.ownerName ?? '').trim().toLowerCase();
    final phoneDigits = _digitsOnly(customer.phone);
    final route = _routeLabelForCustomer(
      customer,
      routes,
      routesLoaded: routesLoaded,
    ).toLowerCase();

    if (query.isNotEmpty && name == query) return 0;
    if (queryDigits.isNotEmpty && phoneDigits == queryDigits) return 1;
    if (query.isNotEmpty && name.startsWith(query)) return 2;
    if (query.isNotEmpty && owner.startsWith(query)) return 3;
    if (query.isNotEmpty && route.startsWith(query)) return 4;
    if (query.isNotEmpty && name.contains(query)) return 5;
    if (query.isNotEmpty && owner.contains(query)) return 6;
    if (query.isNotEmpty && route.contains(query)) return 7;
    if (queryDigits.isNotEmpty && phoneDigits.contains(queryDigits)) return 8;
    return 999;
  }

  bool _canGoNextFromStep({required bool hasSelectedUnits}) {
    return switch (_step) {
      0 => _selectedCustomer != null,
      1 => _orderType != null,
      2 => hasSelectedUnits,
      _ => true,
    };
  }

  String _primaryBarLeftCaption({
    required bool hasSelectedUnits,
    required _SelectionSummary selection,
    required double total,
  }) {
    switch (_step) {
      case 0:
        final c = _selectedCustomer;
        if (c == null) return 'Choose a customer to enable Continue.';
        return '${c.name} · ${c.phone}';
      case 1:
        final run = _deliveryRun.label;
        return switch (_orderType) {
          OrderType.daily => '$run · Daily order.',
          OrderType.oneTime => '$run · One-time order.',
          OrderType.special => '$run · Special order.',
          null => '$run run — choose an order type.',
        };
      case 2:
        if (!hasSelectedUnits) {
          return 'Add at least one menu item to enable Continue.';
        }
        return '${selection.distinctItems} products · ${selection.totalUnits} units.';
      case 3:
        final name = _selectedCustomer?.name ?? '';
        return name.isEmpty
            ? 'Total ${_formatRupee(total)}'
            : 'Total ${_formatRupee(total)} · $name';
      default:
        return '';
    }
  }

  void _onPrimaryStepAction({required bool hasSelectedUnits}) {
    if (_step < 3) {
      if (!_canGoNextFromStep(hasSelectedUnits: hasSelectedUnits)) return;
      try {
        HapticFeedback.lightImpact();
      } catch (_) {}
      setState(() => _step += 1);
      return;
    }
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
    _submitOrder();
  }

  Widget _buildReviewStep({
    required List<FoodItem> foodItems,
    required _SelectionSummary selection,
    required double orderTotal,
  }) {
    final selectedLines =
        _selectedItems.entries
            .where((e) => e.value > 0)
            .map((e) {
              final item = foodItems.firstWhereOrNull((f) => f.id == e.key);
              return item == null ? null : (item, e.value);
            })
            .whereType<(FoodItem, int)>()
            .toList()
          ..sort((a, b) => a.$1.name.compareTo(b.$1.name));

    final reportLines = <_ReportLineItem>[
      for (final (item, qty) in selectedLines)
        _ReportLineItem(
          name: item.name,
          quantity: qty,
          unitPrice: _effectiveUnitPrice(item),
          lineTotal: _effectiveUnitPrice(item) * qty,
          isCustomRate: _customUnitPrices.containsKey(item.id),
        ),
    ];

    final existing = _editingOrder;
    final mergeTarget = existing == null && _orderType != OrderType.special
        ? _findMergeTarget()
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderReviewReport(
          generatedAt: DateTime.now(),
          lines: reportLines,
          orderTotal: orderTotal,
          lineCount: selection.distinctItems,
          unitCount: selection.totalUnits,
        ),
        if (existing == null && !widget.forDriver) ...[
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create separate order',
                          style: context.appTextStyles.sectionHeader.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mergeTarget == null
                              ? 'Creates a new ${_deliveryRun.label.toLowerCase()} order for this customer (today\'s kitchen day, after ${formatOrderRolloverLabel(ref.watch(orderRolloverHourProvider))}).'
                              : (_createSeparateOrder
                                    ? 'Creates a new order. Turn off to add items to today\'s ${_deliveryRun.label.toLowerCase()} order instead.'
                                    : 'Items will be added to today\'s ${_deliveryRun.label.toLowerCase()} order (same run, after reset time). Turn on for a separate order.'),
                          style: context.appTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Switch.adaptive(
                    value: _createSeparateOrder,
                    onChanged: (v) => setState(() => _createSeparateOrder = v),
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.35),
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  double _effectiveUnitPrice(FoodItem item) {
    return _customUnitPrices[item.id] ?? item.price;
  }

  Order? _findMergeTarget() {
    final customer = _selectedCustomer;
    if (customer == null) return null;
    final orderType = _orderType;
    if (orderType == null) return null;
    return findMergeTargetOrder(
      orders: ref.read(ordersProvider),
      customerId: customer.id,
      orderType: orderType,
      deliveryRun: _deliveryRun,
      referenceTime: DateTime.now(),
      rolloverHour: ref.read(orderRolloverHourProvider),
      forDriver: widget.forDriver,
    );
  }

  void _showCustomPriceDialog(FoodItem item, {VoidCallback? onApplied}) {
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
                  hintText: 'Default: ${_formatRupee(item.price)}',
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
                  onApplied?.call();
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
                  onApplied?.call();
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
                onApplied?.call();
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
                style: TextStyle(fontWeight: FontWeight.w900),
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
    required String? driverRouteId,
  }) {
    if (!customersLoaded && customers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final showRouteLoading = !routesLoaded && routes.isEmpty;

    final q = _customerSearchQuery.trim().toLowerCase();
    final qDigits = _digitsOnly(_customerSearchQuery);
    final filteredCustomers =
        customers
            .map(
              (customer) => (
                customer: customer,
                score: _customerMatchScore(
                  customer,
                  q,
                  qDigits,
                  routes,
                  routesLoaded: routesLoaded,
                ),
              ),
            )
            .where(
              (entry) =>
                  q.isEmpty && qDigits.isEmpty ? true : entry.score < 999,
            )
            .toList()
          ..sort((a, b) {
            final byScore = a.score.compareTo(b.score);
            if (byScore != 0) return byScore;
            return a.customer.name.toLowerCase().compareTo(
              b.customer.name.toLowerCase(),
            );
          });
    final visibleCustomers = filteredCustomers
        .map((entry) => entry.customer)
        .toList();
    final searchActive = q.isNotEmpty || qDigits.isNotEmpty;

    final selected = _selectedCustomer;

    void onCustomerChosen(Customer customer) {
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
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _customerSearchController ??= TextEditingController(
            text: _customerSearchQuery,
          ),
          onChanged: (val) => setState(() => _customerSearchQuery = val),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Search by customer, owner, route, or phone',
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.textLight,
            ),
            suffixIcon: searchActive
                ? IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _customerSearchController?.clear();
                      setState(() => _customerSearchQuery = '');
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textLight,
                    ),
                  )
                : null,
            filled: true,
            fillColor: AppColors.backgroundSecondary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (selected != null)
          _SelectedPartnerCard(
            customer: selected,
            routeName: _routeLabelForCustomer(
              selected,
              routes,
              routesLoaded: routesLoaded,
            ),
            onChange: () => setState(() => _selectedCustomer = null),
          )
        else if (customers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.forDriver
                  ? ((driverRouteId == null || driverRouteId.isEmpty)
                        ? 'No route assigned yet. Ask the owner to assign your route first.'
                        : 'No customers found on your assigned route yet.')
                  : 'No customers yet — add one in Customers first.',
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    searchActive
                        ? '${visibleCustomers.length} match${visibleCustomers.length == 1 ? '' : 'es'}'
                        : 'All customers (${visibleCustomers.length})',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (searchActive)
                  Text(
                    'Tap a result to continue',
                    style: TextStyle(
                      color: AppColors.textLight.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          _CustomerSuggestions(
            customers: visibleCustomers,
            showRouteLoading: showRouteLoading,
            routes: routes,
            searchQuery: _customerSearchQuery.trim(),
            onClearSearch: searchActive
                ? () {
                    _customerSearchController?.clear();
                    setState(() => _customerSearchQuery = '');
                  }
                : null,
            emptyHint: q.isEmpty && qDigits.isEmpty
                ? 'No customers to show.'
                : 'No customers match that search. Try a different name, owner, route, or phone.',
            onSelect: onCustomerChosen,
          ),
        ],
      ],
    );
  }

  void _openItemsSheet(List<FoodItem> foodItems) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void refreshSheet() => setModalState(() {});

            final sheetLineCount = _selectedItems.entries
                .where((e) => e.value > 0)
                .length;
            final sheetUnitCount = _selectedItems.entries
                .where((e) => e.value > 0)
                .fold<int>(0, (sum, e) => sum + e.value);

            return DraggableScrollableSheet(
              initialChildSize: 0.86,
              minChildSize: 0.45,
              maxChildSize: 0.96,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Menu',
                                  style: context.appTextStyles.sectionHeader,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  sheetLineCount == 0
                                      ? 'Nothing selected yet — use + to add.'
                                      : '$sheetLineCount line${sheetLineCount == 1 ? '' : 's'} · $sheetUnitCount units in this order',
                                  style: context.appTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _itemSearchController ??=
                            TextEditingController(text: _itemSearchQuery),
                        onChanged: (val) {
                          setState(() => _itemSearchQuery = val);
                          refreshSheet();
                        },
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search by item name',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppColors.textLight,
                          ),
                          filled: true,
                          fillColor: AppColors.backgroundSecondary,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _CatalogList(
                          controller: scrollController,
                          items: _filterCatalog(foodItems),
                          getQty: (id) => _selectedItems[id] ?? 0,
                          getUnitPrice: _effectiveUnitPrice,
                          isCustom: (id) => _customUnitPrices.containsKey(id),
                          onCustomPrice: (item) => _showCustomPriceDialog(
                            item,
                            onApplied: refreshSheet,
                          ),
                          onInc: (id) {
                            setState(
                              () => _selectedItems[id] =
                                  (_selectedItems[id] ?? 0) + 1,
                            );
                            final controller = _catalogQtyControllers[id];
                            if (controller != null) {
                              controller.text = (_selectedItems[id] ?? 0)
                                  .toString();
                              controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length),
                              );
                            }
                            refreshSheet();
                          },
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
                            final controller = _catalogQtyControllers[id];
                            if (controller != null) {
                              controller.text = (_selectedItems[id] ?? 0)
                                  .toString();
                              controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length),
                              );
                            }
                            refreshSheet();
                          },
                          getQtyController: _catalogQtyControllerFor,
                          onQtyChanged: (id, nextQty) {
                            setState(() {
                              final safe = nextQty.clamp(0, 999);
                              if (safe <= 0) {
                                _selectedItems.remove(id);
                                _customUnitPrices.remove(id);
                                _removeCatalogQtyController(id);
                              } else {
                                _selectedItems[id] = safe;
                              }
                            });
                            refreshSheet();
                          },
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: Text(
                                'Done',
                                style: context.appTextStyles.buttonLabel
                                    .copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(_disposeCatalogQtyControllers);
  }

  List<FoodItem> _filterCatalog(List<FoodItem> foodItems) {
    final q = _itemSearchQuery.trim().toLowerCase();
    if (q.isEmpty) return foodItems;
    return foodItems.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  Widget _buildSelectedItemsList(
    List<FoodItem> foodItems, {
    required bool catalogLoaded,
    VoidCallback? onBrowseCatalog,
  }) {
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_rounded,
              size: 32,
              color: AppColors.textLight.withValues(alpha: 0.85),
            ),
            const SizedBox(height: 10),
            Text(
              catalogLoaded ? 'No items yet' : 'Loading catalog…',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              catalogLoaded
                  ? 'Browse your menu and set quantities — you can search inside the sheet.'
                  : 'Hang tight while products load.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (catalogLoaded && onBrowseCatalog != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onBrowseCatalog,
                icon: const Icon(Icons.open_in_new_rounded, size: 20),
                label: const Text(
                  'Browse menu',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final selectedIds = selected.map((e) => e.$1.id).toSet();
    final staleIds = _qtyControllers.keys.where(
      (k) => !selectedIds.contains(k),
    );
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
    Widget pill(
      String label,
      bool selected,
      VoidCallback onTap, {
      bool expanded = false,
      EdgeInsetsGeometry? padding,
    }) {
      final chip = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding:
              padding ?? const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      );
      return expanded ? Expanded(child: chip) : chip;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Delivery run',
          style: context.appTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: DeliveryRun.values.map((run) {
            return pill(
              run.label,
              _deliveryRun == run,
              () => setState(() => _deliveryRun = run),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          'Order type',
          style: context.appTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            pill(
              'Daily order',
              _orderType == OrderType.daily,
              () => setState(() => _orderType = OrderType.daily),
              expanded: true,
            ),
            const SizedBox(width: 10),
            pill(
              'One-time',
              _orderType == OrderType.oneTime,
              () => setState(() => _orderType = OrderType.oneTime),
              expanded: true,
            ),
            const SizedBox(width: 10),
            pill(
              'Special',
              _orderType == OrderType.special,
              () => setState(() {
                _orderType = OrderType.special;
                _createSeparateOrder = true;
              }),
              expanded: true,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          switch (_orderType) {
            OrderType.daily =>
              'Recurring daily order. Same customer can have another run today (e.g. evening) as a separate order.',
            OrderType.oneTime =>
              'A single delivery — labeled as a one-time order everywhere.',
            OrderType.special =>
              'A separate order labeled as special. Special orders won’t merge with existing orders.',
            null =>
              'Pick when and how this order should be treated before moving to menu items.',
          },
          style: context.appTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  void _submitOrder() {
    if (_isSubmitting) return;
    if (_selectedCustomer == null) return;
    final orderType = _orderType;
    if (orderType == null) return;
    if (_selectedItems.values.every((v) => v <= 0)) return;
    setState(() => _isSubmitting = true);
    FocusScope.of(context).unfocus();
    final foodItems = ref.read(foodItemsProvider);
    final routes = ref.read(routesProvider);
    final user = ref.read(authProvider).user;
    final drivers = ref.read(driversProvider);
    final driverId = widget.forDriver
        ? (user?.linkedEntityId ?? user?.id)
        : null;
    final currentDriver = widget.forDriver
        ? drivers.firstWhereOrNull((d) => d.id == driverId)
        : null;
    final driverRouteId = currentDriver?.currentRoute?.trim();
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

    if (widget.forDriver) {
      if (driverId == null || driverId.trim().isEmpty) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Driver account not linked. Please sign in again.',
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
      if (driverRouteId == null || driverRouteId.isEmpty) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No route assigned yet. Ask the owner to assign your route first.',
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
      if (!_customerMatchesRoute(
        _selectedCustomer!,
        driverRouteId: driverRouteId,
        routes: routes,
      )) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Choose a customer from your assigned route.',
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
    }

    final route = widget.forDriver
        ? RouteRefs.routeForRef(driverRouteId, routes)
        : RouteRefs.routeForRef(_selectedCustomer!.assignedRoute, routes);
    final normalizedRouteId = route?.id ??
        RouteRefs.routeIdForRef(
          widget.forDriver
              ? driverRouteId
              : _selectedCustomer!.assignedRoute,
          routes,
        );
    final assignedDriver = widget.forDriver ? driverId : route?.assignedDriver;
    const discountAmount = 0.0;
    final totalAmount = subtotal.clamp(0, double.infinity).toDouble();

    final now = DateTime.now();
    final existing = _editingOrder;
    final rolloverHour = ref.read(orderRolloverHourProvider);
    final rolloverLabel = formatOrderRolloverLabel(rolloverHour);
    if (existing != null &&
        !canModifyOrderItems(
          existing,
          referenceTime: now,
          rolloverHour: rolloverHour,
        )) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This order is from before today\'s $rolloverLabel reset. Create a new order instead.',
            style: const TextStyle(fontWeight: FontWeight.w700),
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
    final mergeTarget =
        existing == null &&
            !_createSeparateOrder &&
            orderType != OrderType.special
        ? _findMergeTarget()
        : null;
    final (Order nextOrder, bool wasCreated) = switch ((
      existing,
      mergeTarget,
    )) {
      (null, null) => (
        Order(
          id: const Uuid().v4(),
          factoryId: _selectedCustomer!.factoryId,
          orderType: orderType,
          deliveryRun: _deliveryRun,
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
          assignedRoute: normalizedRouteId,
          assignedDriver: assignedDriver,
          orderDate: now,
          createdAt: now,
          updatedAt: now,
        ),
        true,
      ),
      (final existing?, _) => (
        existing.copyWith(
          factoryId: _selectedCustomer!.factoryId,
          orderType: orderType,
          deliveryRun: _deliveryRun,
          customerId: _selectedCustomer!.id,
          customerName: _selectedCustomer!.name,
          customerEmail: _selectedCustomer!.email,
          customerPhone: _selectedCustomer!.phone,
          customerAddress: _selectedCustomer!.address,
          items: items,
          subtotal: subtotal,
          discountAmount: discountAmount,
          totalAmount: totalAmount,
          assignedRoute: normalizedRouteId,
          assignedDriver: assignedDriver,
          updatedAt: now,
        ),
        false,
      ),
      (_, final mergeTarget?) => (
        _mergeIntoExistingOrder(
          mergeTarget: mergeTarget,
          addedItems: items,
          customer: _selectedCustomer!,
          orderType: orderType,
          assignedRoute: normalizedRouteId,
          assignedDriver: assignedDriver,
          now: now,
        ),
        false,
      ),
    };

    if (wasCreated) {
      ref.read(ordersProvider.notifier).addOrder(nextOrder);
    } else {
      ref.read(ordersProvider.notifier).updateOrder(nextOrder);
    }
    try {
      ref
          .read(lastTouchedOrderProvider.notifier)
          .set(id: nextOrder.id, wasCreated: wasCreated);
    } catch (_) {}
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasCreated
              ? 'Order created successfully'
              : (mergeTarget == null ? 'Order updated' : 'Order updated'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    context.pop();
  }

  Order _mergeIntoExistingOrder({
    required Order mergeTarget,
    required List<OrderItem> addedItems,
    required Customer customer,
    required OrderType orderType,
    required String? assignedRoute,
    required String? assignedDriver,
    required DateTime now,
  }) {
    final merged = List<OrderItem>.from(mergeTarget.items);
    for (final add in addedItems) {
      final i = merged.indexWhere((m) => m.foodItemId == add.foodItemId);
      if (i < 0) {
        merged.add(add);
        continue;
      }
      final old = merged[i];
      final nextQty = old.quantity + add.quantity;
      final unitPrice = add.unitPrice;
      merged[i] = OrderItem(
        id: old.id,
        foodItemId: old.foodItemId,
        foodItemName: old.foodItemName,
        quantity: nextQty,
        unitPrice: unitPrice,
        totalPrice: unitPrice * nextQty,
      );
    }
    final nextSubtotal = merged.fold<double>(0, (sum, i) => sum + i.totalPrice);
    final nextTotal = (nextSubtotal - mergeTarget.discountAmount)
        .clamp(0, double.infinity)
        .toDouble();

    return mergeTarget.copyWith(
      factoryId: customer.factoryId,
      orderType: orderType,
      customerId: customer.id,
      customerName: customer.name,
      customerEmail: customer.email,
      customerPhone: customer.phone,
      customerAddress: customer.address,
      items: merged,
      subtotal: nextSubtotal,
      totalAmount: nextTotal,
      assignedRoute: assignedRoute,
      assignedDriver: assignedDriver,
      updatedAt: now,
    );
  }
}
