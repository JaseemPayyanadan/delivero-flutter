import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/food_item.dart';
import '../../../data/models/order.dart';
import '../../../data/models/delivery_route.dart';

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
  const CreateOrderScreen({super.key, this.orderId});

  @override
  ConsumerState<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends ConsumerState<CreateOrderScreen> {
  static const int _stepCount = 4;
  static const List<String> _stepTitles = [
    'Customer',
    'Order type',
    'Menu items',
    'Order details',
  ];

  Customer? _selectedCustomer;
  OrderType _orderType = OrderType.daily;
  Map<String, int> _selectedItems = {}; // foodItemId -> quantity
  Map<String, double> _customUnitPrices = {}; // foodItemId -> unit price
  bool _isSubmitting = false;
  bool _initializedFromOrder = false;
  Order? _editingOrder;
  final Map<String, TextEditingController> _qtyControllers = {};
  /// 0 = customer, 1 = order type, 2 = menu, 3 = review.
  int _step = 0;

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
    final canPrimaryProceed = !_isSubmitting && _canGoNextFromStep(
      hasSelectedUnits: hasSelectedUnits,
    );
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
      0 => widget.orderId == null
          ? 'Step 1 of 4 — Search and choose who this order is for.'
          : 'Step 1 of 4 — Customer for this order.',
      1 => 'Step 2 of 4 — Daily recurring or a single one-time delivery.',
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
          title: widget.orderId == null ? 'Create order' : 'Edit order',
          leading:
              (Navigator.of(context).canPop() || _step > 0)
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
                          customers,
                          routes,
                          customersLoaded: customersLoaded,
                          routesLoaded: routesLoaded,
                        ),
                        1 => _FormSectionCard(
                          title: 'Order type',
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
                          routes: routes,
                          routesLoaded: routesLoaded,
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
                              : (widget.orderId == null
                                    ? 'Confirm'
                                    : 'Update'),
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

  bool _canGoNextFromStep({required bool hasSelectedUnits}) {
    return switch (_step) {
      0 => _selectedCustomer != null,
      1 => true,
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
        return _orderType == OrderType.daily
            ? 'Daily order is selected.'
            : 'One-time order is selected.';
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
      HapticFeedback.lightImpact();
      setState(() => _step += 1);
      return;
    }
    HapticFeedback.heavyImpact();
    _submitOrder();
  }

  String _routeLabel(Customer c, List<DeliveryRoute> routes, bool routesLoaded) {
    if (!routesLoaded) return 'Loading route…';
    return routes
            .firstWhereOrNull(
              (r) =>
                  r.id == c.assignedRoute || r.name == c.assignedRoute,
            )
            ?.name ??
        (c.assignedRoute ?? 'Unassigned');
  }

  Widget _buildReviewStep({
    required List<FoodItem> foodItems,
    required List<DeliveryRoute> routes,
    required bool routesLoaded,
    required _SelectionSummary selection,
    required double orderTotal,
  }) {
    final c = _selectedCustomer!;
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

    return _OrderReviewReport(
      customerName: c.name,
      customerPhone: c.phone,
      customerRoute: _routeLabel(c, routes, routesLoaded),
      orderTypeLabel: _orderType == OrderType.daily
          ? 'Daily order'
          : 'One-time order',
      generatedAt: DateTime.now(),
      lines: reportLines,
      orderTotal: orderTotal,
      lineCount: selection.distinctItems,
      unitCount: selection.totalUnits,
    );
  }

  double _effectiveUnitPrice(FoodItem item) {
    return _customUnitPrices[item.id] ?? item.price;
  }

  void _showCustomPriceDialog(
    FoodItem item, {
    VoidCallback? onApplied,
  }) {
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
  }) {
    if (!customersLoaded && customers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final showRouteLoading = !routesLoaded && routes.isEmpty;

    final q = _customerSearchQuery.trim().toLowerCase();
    final filteredCustomers =
        customers.where((c) {
          if (q.isEmpty) return true;
          return c.name.toLowerCase().contains(q) || c.phone.contains(q);
        }).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

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
            hintText: 'Search by name or phone (optional)',
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
        else if (customers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No customers yet — add one in Customers first.',
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
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'All customers (${filteredCustomers.length})',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          _CustomerSuggestions(
            customers: filteredCustomers,
            showRouteLoading: showRouteLoading,
            routes: routes,
            emptyHint: q.isEmpty
                ? 'No customers to show.'
                : 'No customers match that search. Try a different name or phone.',
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimary,
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
    );
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
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            pill(
              'Daily order',
              _orderType == OrderType.daily,
              () => setState(() => _orderType = OrderType.daily),
            ),
            const SizedBox(width: 10),
            pill(
              'One-time',
              _orderType == OrderType.oneTime,
              () => setState(() => _orderType = OrderType.oneTime),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          _orderType == OrderType.daily
              ? 'Shows as a recurring daily order on your lists and dashboards.'
              : 'A single delivery — labeled as a one-time order everywhere.',
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
    final normalizedRouteId =
        route?.id ??
        (_selectedCustomer!.assignedRoute?.trim().isNotEmpty == true
            ? _selectedCustomer!.assignedRoute!.trim()
            : null);
    final assignedDriver = route?.assignedDriver;
    const discountAmount = 0.0;
    final totalAmount = subtotal.clamp(0, double.infinity).toDouble();

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
            assignedRoute: normalizedRouteId,
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
            assignedRoute: normalizedRouteId,
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

class _CreateOrderStepProgress extends StatelessWidget {
  final int stepIndex;
  final int stepCount;
  final List<String> labels;

  const _CreateOrderStepProgress({
    required this.stepIndex,
    required this.stepCount,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < stepCount; i++) ...[
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= stepIndex
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (i < stepCount - 1) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${labels[stepIndex]} · ${stepIndex + 1}/$stepCount',
          style: context.appTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ReportLineItem {
  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final bool isCustomRate;

  const _ReportLineItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.isCustomRate,
  });
}

class _OrderReviewReport extends StatelessWidget {
  final String customerName;
  final String customerPhone;
  final String customerRoute;
  final String orderTypeLabel;
  final DateTime generatedAt;
  final List<_ReportLineItem> lines;
  final double orderTotal;
  final int lineCount;
  final int unitCount;

  const _OrderReviewReport({
    required this.customerName,
    required this.customerPhone,
    required this.customerRoute,
    required this.orderTypeLabel,
    required this.generatedAt,
    required this.lines,
    required this.orderTotal,
    required this.lineCount,
    required this.unitCount,
  });

  static TextStyle _label(BuildContext context) => const TextStyle(
        color: AppColors.textLight,
        fontWeight: FontWeight.w900,
        fontSize: 11,
        letterSpacing: 1.2,
      );

  @override
  Widget build(BuildContext context) {
    final prepared = DateFormat('EEE, d MMM yyyy · HH:mm').format(generatedAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            color: AppColors.backgroundSecondary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 22,
                      color: AppColors.primary.withValues(alpha: 0.9),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Order summary',
                        style: context.appTextStyles.sectionHeader,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Prepared $prepared · $lineCount line${lineCount == 1 ? '' : 's'} · $unitCount units',
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All amounts in INR',
                  style: context.appTextStyles.caption.copyWith(
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('BILL TO', style: _label(context)),
                const SizedBox(height: 10),
                _ReportKvRow(label: 'Customer', value: customerName),
                _ReportKvRow(label: 'Phone', value: customerPhone),
                _ReportKvRow(label: 'Route', value: customerRoute),
                const SizedBox(height: 14),
                Text('ORDER TYPE', style: _label(context)),
                const SizedBox(height: 6),
                Text(
                  orderTypeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: -0.3,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'LINE ITEMS',
                    style: _label(context),
                  ),
                ),
                const SizedBox(height: 8),
                const _ReportTableHeaderRow(),
                for (var i = 0; i < lines.length; i++) ...[
                  _ReportTableDataRow(line: lines[i]),
                  if (i < lines.length - 1)
                    const Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: AppColors.divider,
                    ),
                ],
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 2,
            color: AppColors.border,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('AMOUNT SUMMARY', style: _label(context)),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Expanded(
                      child: Text(
                        'Order total',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      _formatRupee(orderTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: -0.3,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportKvRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReportKvRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: context.appTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportTableHeaderRow extends StatelessWidget {
  const _ReportTableHeaderRow();

  @override
  Widget build(BuildContext context) {
    final s = context.appTextStyles.caption.copyWith(
      fontWeight: FontWeight.w900,
      fontSize: 11,
      color: AppColors.textSecondary,
      letterSpacing: 0.35,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      color: AppColors.backgroundSecondary,
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Text('ITEM', style: s),
          ),
          Expanded(
            flex: 4,
            child: Text('QTY', style: s, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 5,
            child: Text('RATE', style: s, textAlign: TextAlign.right),
          ),
          Expanded(
            flex: 6,
            child: Text('AMOUNT', style: s, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _ReportTableDataRow extends StatelessWidget {
  final _ReportLineItem line;

  const _ReportTableDataRow({required this.line});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 11,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.25,
                  ),
                ),
                if (line.isCustomRate)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Custom rate',
                      style: context.appTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '${line.quantity}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              _formatRupee(line.unitPrice),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              _formatRupee(line.lineTotal),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _FormSectionCard({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.appTextStyles.sectionHeader,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: context.appTextStyles.caption.copyWith(
                            color: AppColors.textLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 2),
                    child: trailing!,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
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
                    fontSize: 16,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$routeName • ${customer.phone}',
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

class _CustomerSuggestions extends StatelessWidget {
  final List<Customer> customers;
  final bool showRouteLoading;
  final List<DeliveryRoute> routes;
  final ValueChanged<Customer> onSelect;
  final String emptyHint;

  const _CustomerSuggestions({
    required this.customers,
    required this.showRouteLoading,
    required this.routes,
    required this.onSelect,
    this.emptyHint = 'No matching customers',
  });

  @override
  Widget build(BuildContext context) {
    if (customers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(
          emptyHint,
          style: const TextStyle(
            color: AppColors.textLight,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < customers.length; i++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            visualDensity: VisualDensity.compact,
            onTap: () => onSelect(customers[i]),
            leading: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(
                Icons.person_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            title: Text(
              customers[i].name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: -0.45,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              '${showRouteLoading ? 'Loading route…' : (routes.firstWhereOrNull((r) => r.id == customers[i].assignedRoute || r.name == customers[i].assignedRoute)?.name ?? 'No Route')} • ${customers[i].phone}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (i != customers.length - 1)
            const Divider(height: 1, color: AppColors.divider),
        ],
      ],
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
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                    fontSize: 16,
                    letterSpacing: -0.45,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _formatRupee(unitPrice),
                      style: TextStyle(
                        color: isCustom
                            ? AppColors.primary
                            : AppColors.textLight,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
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
                            color: AppColors.primaryLighter.withValues(
                              alpha: 0.9,
                            ),
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
            icon: const Icon(Icons.remove_rounded, size: 16),
            color: AppColors.textPrimary,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
          SizedBox(
            width: 32,
            child: controller == null || onQtyChanged == null
                ? Center(
                    child: Text(
                      qty.toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
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
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
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
            icon: const Icon(Icons.add_rounded, size: 16),
            color: AppColors.textPrimary,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
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
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(16),
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
                        fontSize: 16,
                        letterSpacing: -0.45,
                        color: AppColors.textPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${_formatRupee(unitPrice)} / unit',
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
