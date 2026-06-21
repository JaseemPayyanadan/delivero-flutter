import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../../app/providers.dart';
import '../../../app/order_settings_provider.dart';
import '../../../core/orders/business_day.dart';
import '../../../core/orders/order_sort.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/route_refs.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../data/models/order.dart';
import '../../../data/models/delivery_route.dart';
import 'production_summary_sheet.dart';
import 'widgets/order_card.dart';

class OrderListScreen extends ConsumerStatefulWidget {
  const OrderListScreen({super.key});

  @override
  ConsumerState<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends ConsumerState<OrderListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedRouteId;
  PaymentStatus? _selectedPaymentStatus;
  OrderStatus? _selectedOrderStatus;
  DateTime? _productionDay;
  DateTime? _selectedDate;
  Timer? _highlightClearTimer;

  String _formatBusinessDaySection(
    DateTime dayKey,
    DateTime todayKey,
  ) {
    final normalizedDay = DateTime(dayKey.year, dayKey.month, dayKey.day);
    final normalizedToday = DateTime(
      todayKey.year,
      todayKey.month,
      todayKey.day,
    );
    if (normalizedDay == normalizedToday) return 'Today';
    final yesterday = normalizedToday.subtract(const Duration(days: 1));
    if (normalizedDay == yesterday) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(normalizedDay);
  }

  void _scheduleHighlightClear() {
    _highlightClearTimer?.cancel();
    _highlightClearTimer = Timer(const Duration(seconds: 9), () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _highlightClearTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  DateTime _calendarDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String? _routeLabelForId(String? routeId, List<DeliveryRoute> routes) {
    if (routeId == null) return null;
    return routes.firstWhereOrNull((r) => r.id == routeId)?.name;
  }

  Future<void> _pickProductionDay(DateTime currentDay) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: currentDay,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _productionDay = _calendarDay(picked));
    }
  }

  Future<void> _openProductionSummary({
    required List<Order> orders,
    required List<DeliveryRoute> routes,
    required DateTime productionDay,
    required int rolloverHour,
  }) async {
    final routeLabel = _selectedRouteId == null
        ? 'All routes'
        : _routeLabelForId(_selectedRouteId, routes);

    await showProductionSummaryForOrders(
      context,
      allOrders: orders,
      routes: routes,
      day: _calendarDay(productionDay),
      routeId: _selectedRouteId,
      routeLabel: routeLabel,
      rolloverHour: rolloverHour,
      onChangeDate: () async {
        Navigator.pop(context);
        await _pickProductionDay(productionDay);
        if (!mounted) return;
        await _openProductionSummary(
          orders: orders,
          routes: routes,
          productionDay: _productionDay ?? productionDay,
          rolloverHour: rolloverHour,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(lastTouchedOrderProvider, (prev, next) {
      if (next != null) _scheduleHighlightClear();
    });

    final rolloverHour = ref.watch(orderRolloverHourProvider);
    final productionDay =
        _productionDay ?? currentBusinessDayKey(rolloverHour: rolloverHour);
    if (_productionDay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _productionDay != null) return;
        setState(() => _productionDay = productionDay);
      });
    }

    final orders = ref.watch(ordersProvider);
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final routes = ref.watch(routesProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    final bool noOrdersYet = orders.isEmpty;

    String? routeIdForOrder(Order o) =>
        RouteRefs.routeIdForRef(o.assignedRoute, routes) ??
        o.assignedRoute?.trim();

    // Get unique route IDs from existing orders
    final availableRouteIds = orders
        .map(routeIdForOrder)
        .whereType<String>()
        .toSet()
        .toList();

    if (routesLoaded &&
        _selectedRouteId != null &&
        !availableRouteIds.contains(_selectedRouteId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedRouteId = null);
      });
    }

    final filteredOrders = orders.where((order) {
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty
          ? true
          : order.customerName.toLowerCase().contains(q) ||
                order.id.toLowerCase().contains(q) ||
                order.customerPhone.contains(_searchQuery.trim()) ||
                order.customerAddress.toLowerCase().contains(q) ||
                order.customerEmail.toLowerCase().contains(q);

      final matchesRoute = switch (_selectedRouteId) {
        null => true,
        _ => routeIdForOrder(order) == _selectedRouteId,
      };

      final paymentStatus = order.paymentStatus ?? PaymentStatus.unpaid;
      final matchesPayment = _selectedPaymentStatus == null
          ? true
          : paymentStatus == _selectedPaymentStatus;

      final matchesOrderStatus = _selectedOrderStatus == null
          ? true
          : order.status == _selectedOrderStatus;

      final matchesDay = _selectedDate == null
          ? true
          : businessDayKey(order.orderDate, rolloverHour: rolloverHour) ==
              _selectedDate;

      return matchesSearch &&
          matchesRoute &&
          matchesPayment &&
          matchesOrderStatus &&
          matchesDay;
    }).toList();

    sortOrdersByDate(filteredOrders);

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Orders',
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          if (!noOrdersYet)
            IconButton(
              tooltip: 'Production list',
              onPressed: () => _openProductionSummary(
                orders: orders,
                routes: routes,
                productionDay: productionDay,
                rolloverHour: rolloverHour,
              ),
              icon: const Icon(
                Icons.inventory_2_rounded,
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
          IconButton(
            tooltip: 'Filter',
            onPressed: () => _showFiltersSheet(context),
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
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
            if (!noOrdersYet)
              SliverToBoxAdapter(
                child: _buildFilters(
                  routes,
                  availableRouteIds,
                  routesLoaded: routesLoaded,
                ),
              ),
            if (!ordersLoaded && orders.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredOrders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(hasAnyOrders: !noOrdersYet),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                sliver: Builder(
                  builder: (context) {
                    final widgets = _buildGroupedOrderWidgets(
                      filteredOrders,
                      rolloverHour: rolloverHour,
                    );
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => widgets[index],
                        childCount: widgets.length,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedOrderWidgets(
    List<Order> filteredOrders, {
    required int rolloverHour,
  }) {
    final todayKey = currentBusinessDayKey(rolloverHour: rolloverHour);
    final groups = <DateTime, List<Order>>{};

    for (final order in filteredOrders) {
      final dayKey = businessDayKey(order.orderDate, rolloverHour: rolloverHour);
      final normalized = DateTime(dayKey.year, dayKey.month, dayKey.day);
      (groups[normalized] ??= []).add(order);
    }

    final sortedDays = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (final day in sortedDays) {
      final orders = groups[day]!..sort(
        (a, b) => compareOrdersByDate(a, b),
      );
      widgets.add(
        _DateSectionHeader(
          title: _formatBusinessDaySection(day, todayKey),
          count: orders.length,
        ),
      );
      for (final o in orders) {
        widgets.add(OrderCard(order: o, siblingOrders: orders));
      }
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Widget _buildFilters(
    List<DeliveryRoute> routes,
    List<String> availableRouteIds, {
    required bool routesLoaded,
  }) {
    final hasRouteFilter = availableRouteIds.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekStrip(
          selectedDate: _selectedDate,
          onDayTap: (date) => setState(() => _selectedDate = date),
        ),
        if (hasRouteFilter) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildRouteChip(
                    null,
                    'All Routes',
                    routesLoaded: routesLoaded,
                  ),
                  const SizedBox(width: 2),
                  if (!routesLoaded && routes.isEmpty)
                    _buildRouteChip(
                      'loading',
                      'Loading…',
                      routesLoaded: routesLoaded,
                    ),
                  ...availableRouteIds
                      .sortedBy(
                        (id) =>
                            routes.firstWhereOrNull((r) => r.id == id)?.name ??
                            '',
                      )
                      .map((routeId) {
                        final route = routes.firstWhereOrNull(
                          (r) => r.id == routeId,
                        );
                        return _buildRouteChip(
                          routeId,
                          route?.name ?? routeId,
                          routesLoaded: routesLoaded,
                        );
                      }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRouteChip(
    String? routeId,
    String label, {
    required bool routesLoaded,
  }) {
    final isLoading = routeId == 'loading';
    final isSelected = !isLoading && _selectedRouteId == routeId;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: (isLoading || (!routesLoaded && routeId != null))
            ? null
            : () {
                setState(() {
                  _selectedRouteId = isSelected ? null : routeId;
                });
              },
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
                  : isLoading || (!routesLoaded && routeId != null)
                  ? AppColors.textDisabled
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

  Future<void> _showFiltersSheet(BuildContext context) async {
    final res =
        await showModalBottomSheet<
          ({bool clearAll, PaymentStatus? payment, OrderStatus? status})?
        >(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                PaymentStatus? payment = _selectedPaymentStatus;
                OrderStatus? status = _selectedOrderStatus;

                Widget chip<T>({
                  required T? value,
                  required T? selected,
                  required String label,
                  required void Function(T? next) onPick,
                }) {
                  final isSelected = value == selected;
                  return ChoiceChip(
                    selected: isSelected,
                    label: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? Theme.of(context).colorScheme.onPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.backgroundSecondary,
                    onSelected: (_) => setModalState(() {
                      onPick(isSelected ? null : value);
                    }),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  );
                }

                return SafeArea(
                  top: false,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      16 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.border,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Payment',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            chip(
                              value: PaymentStatus.paid,
                              selected: payment,
                              label: 'Paid',
                              onPick: (v) => payment = v,
                            ),
                            chip(
                              value: PaymentStatus.partial,
                              selected: payment,
                              label: 'Partial',
                              onPick: (v) => payment = v,
                            ),
                            chip(
                              value: PaymentStatus.unpaid,
                              selected: payment,
                              label: 'Unpaid',
                              onPick: (v) => payment = v,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Order status',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final s in OrderStatus.values)
                              chip(
                                value: s,
                                selected: status,
                                label: s.label,
                                onPick: (v) => status = v,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  try {
                                    HapticFeedback.lightImpact();
                                  } catch (_) {}
                                  Navigator.pop(context, (
                                    clearAll: true,
                                    payment: null,
                                    status: null,
                                  ));
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Clear',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () {
                                  try {
                                    HapticFeedback.mediumImpact();
                                  } catch (_) {}
                                  Navigator.pop(context, (
                                    clearAll: false,
                                    payment: payment,
                                    status: status,
                                  ));
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'Apply',
                                  style: TextStyle(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );

    if (!mounted || res == null) return;
    setState(() {
      _selectedPaymentStatus = res.clearAll ? null : res.payment;
      _selectedOrderStatus = res.clearAll ? null : res.status;
      if (res.clearAll) _selectedDate = null;
    });
  }

  Future<void> _openSearchSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _OrdersSearchSheet(
          controller: _searchController,
          initialQuery: _searchQuery,
          onChanged: (q) => setState(() => _searchQuery = q),
          onClear: () {
            _searchController.clear();
            setState(() => _searchQuery = '');
          },
        );
      },
    );
  }

  Widget _buildEmptyState({required bool hasAnyOrders}) {
    return DeliveroEmptyState(
      title: hasAnyOrders ? 'No transactions found' : 'No orders yet',
      subtitle: hasAnyOrders
          ? 'Try adjusting your filters or search terms'
          : 'Create your first order to see it here.',
      icon: Icons.receipt_long_rounded,
      actionLabel: hasAnyOrders ? null : 'Create order',
      onActionPressed: hasAnyOrders
          ? null
          : () => context.push('/owner/orders/create'),
    );
  }
}

class _OrdersSearchSheet extends StatelessWidget {
  final TextEditingController controller;
  final String initialQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _OrdersSearchSheet({
    required this.controller,
    required this.initialQuery,
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

class _WeekStrip extends StatelessWidget {
  final DateTime? selectedDate;
  final void Function(DateTime?) onDayTap;

  const _WeekStrip({required this.selectedDate, required this.onDayTap});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final daysFromSunday = now.weekday == 7 ? 0 : now.weekday;
    final sunday = todayKey.subtract(Duration(days: daysFromSunday));
    final days = List.generate(7, (i) => sunday.add(Duration(days: i)));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: days.map((day) {
          final isToday = day == todayKey;
          final isSelected = selectedDate == day;
          final isPast = day.isBefore(todayKey);
          return _DayCell(
            day: day,
            isToday: isToday,
            isSelected: isSelected,
            isPast: isPast,
            onTap: () => onDayTap(isSelected ? null : day),
          );
        }).toList(),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isPast;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isPast,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color nameColor;
    final Color numColor;
    if (isSelected) {
      nameColor = AppColors.primary;
      numColor = Colors.white;
    } else if (isToday) {
      nameColor = AppColors.primary;
      numColor = AppColors.primary;
    } else if (isPast) {
      nameColor = AppColors.textLight;
      numColor = AppColors.textLight;
    } else {
      nameColor = AppColors.textSecondary;
      numColor = AppColors.textPrimary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('EEE').format(day),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: nameColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : isToday
                      ? AppColors.primaryLighter
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                day.day.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: numColor,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: isToday ? AppColors.primary : Colors.transparent,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _DateSectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  color: AppColors.textLight,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$count ${count == 1 ? 'Order' : 'Orders'}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
