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
import '../../../core/orders/daily_order_recreation_service.dart';
import '../../../core/orders/order_sort.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/route_refs.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../data/models/order.dart';
import '../../../data/models/delivery_route.dart';
import 'production_summary_sheet.dart';
import 'day_strip_math.dart';
import 'unresolved_orders_sheet.dart';
import 'widgets/order_card.dart';

/// Fixed height for the swipeable day strip (a horizontal scroll list needs
/// bounded height). Sized to comfortably fit one row of day cells.
const double _kDayStripHeight = 88;

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
  // When set, the list shows every order whose day falls in this inclusive
  // range (grouped by day). Mutually exclusive with [_selectedDate].
  DateTimeRange? _selectedRange;
  bool _selectedDateInitialized = false;
  Timer? _highlightClearTimer;
  final ScrollController _dayScrollController = ScrollController();
  bool _dayStripPositioned = false;
  double _dayCellWidth = 0;
  DateTime? _visibleLeadDate;

  Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

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

  Future<void> _bulkMarkDelivered(List<Order> allOrders) async {
    final now = DateTime.now();
    final targets = allOrders
        .where((o) =>
            _selectedIds.contains(o.id) && o.status != OrderStatus.delivered)
        .toList();
    for (final order in targets) {
      final updated = order.copyWith(
        status: OrderStatus.delivered,
        deliveryTime: order.deliveryTime ?? now,
        deliveryDate: order.deliveryDate ?? now,
        updatedAt: now,
      );
      await ref.read(ordersProvider.notifier).updateOrder(updated);
    }
    if (mounted) {
      setState(() => _selectedIds = {});
      if (targets.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${targets.length} orders marked as delivered')),
        );
      }
    }
  }

  Future<void> _bulkMarkPaid(List<Order> allOrders) async {
    final now = DateTime.now();
    final targets = allOrders
        .where((o) =>
            _selectedIds.contains(o.id) &&
            o.paymentStatus != PaymentStatus.paid)
        .toList();
    for (final order in targets) {
      final updated = order.copyWith(
        paymentStatus: PaymentStatus.paid,
        paymentMethod: order.paymentMethod ?? PaymentMethod.cash,
        paymentTime: now,
        updatedAt: now,
      );
      await ref.read(ordersProvider.notifier).updateOrder(updated);
    }
    if (mounted) {
      setState(() => _selectedIds = {});
      if (targets.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${targets.length} orders marked as paid')),
        );
      }
    }
  }

  @override
  void dispose() {
    _dayScrollController.dispose();
    _highlightClearTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Update the header's lead-date label from the strip's current scroll
  /// position (the leftmost day in view).
  void _updateVisibleLeadDate() {
    if (!_dayScrollController.hasClients || _dayCellWidth <= 0) return;
    final leadIndex = (_dayScrollController.offset / _dayCellWidth).round();
    final lead = dayForIndex(DateTime.now(), leadIndex);
    if (lead != _visibleLeadDate) {
      setState(() => _visibleLeadDate = lead);
    }
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

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial =
        _selectedRange ??
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: _calendarDay(now),
        );
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(2023),
      lastDate: now.add(const Duration(days: 365)),
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
      setState(() {
        // Range and single-day selection are mutually exclusive.
        _selectedRange = DateTimeRange(
          start: _calendarDay(picked.start),
          end: _calendarDay(picked.end),
        );
        _selectedDate = null;
      });
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

    // Select today's calendar day on first open. Orders are grouped by their
    // stored calendar date, so the selection, the strip highlight and the list
    // grouping all agree on the same "today". A one-shot flag keeps this from
    // re-selecting after the user clears the day filter.
    if (!_selectedDateInitialized) {
      _selectedDateInitialized = true;
      _selectedDate = _calendarDay(DateTime.now());
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

    // Calendar days that contain orders (respecting only the route filter, so
    // the strip's dots match what tapping a day shows). Used for the day-strip
    // markers and the empty-state "nearest day with orders" hint.
    final daysWithOrders = <DateTime>{
      for (final o in orders)
        if (_selectedRouteId == null || routeIdForOrder(o) == _selectedRouteId)
          _calendarDay(o.orderDate),
    };

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

      // Orders already store orderDate stamped at the business-day rollover
      // hour, so the order's calendar date IS its business day. Match on that
      // directly (matching the calendar-day strip); re-applying the rollover
      // here would file the order a day early and hide it. A range filter, when
      // active, takes priority over the single-day selection.
      // While a search is active, ignore the day/range filter so search spans
      // every date (find a customer's order regardless of when it was placed).
      final orderDay = _calendarDay(order.orderDate);
      final bool matchesDay;
      if (q.isNotEmpty) {
        matchesDay = true;
      } else if (_selectedRange != null) {
        matchesDay = !orderDay.isBefore(_selectedRange!.start) &&
            !orderDay.isAfter(_selectedRange!.end);
      } else if (_selectedDate != null) {
        matchesDay = orderDay == _selectedDate;
      } else {
        matchesDay = true;
      }

      return matchesSearch &&
          matchesRoute &&
          matchesPayment &&
          matchesOrderStatus &&
          matchesDay;
    }).toList();

    sortOrdersByDate(filteredOrders);

    // Tell the shell whether this view is empty so it can hide the "+" FAB
    // (the empty states carry their own actions).
    final viewIsEmpty = filteredOrders.isEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(ordersViewIsEmptyProvider.notifier).set(viewIsEmpty);
      }
    });

    return PopScope(
      canPop: !_isSelecting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSelecting) {
          setState(() => _selectedIds = {});
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: _isSelecting ? '${_selectedIds.length} selected' : 'Orders',
        leading: _isSelecting
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => setState(() => _selectedIds = {}),
              )
            : Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.pop(),
                  )
                : null,
        actions: _isSelecting
            ? []
            : [
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
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isSelecting
            ? SafeArea(
                key: const ValueKey('bulk-bar'),
                child: Consumer(
                  builder: (context, ref, _) {
                    final allOrders = ref.watch(ordersProvider);
                    final selectedOrders =
                        allOrders.where((o) => _selectedIds.contains(o.id)).toList();
                    final allDelivered = selectedOrders.isEmpty ||
                        selectedOrders.every((o) => o.status == OrderStatus.delivered);
                    final allPaid = selectedOrders.isEmpty ||
                        selectedOrders.every((o) => o.paymentStatus == PaymentStatus.paid);
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: allDelivered
                                  ? null
                                  : () => _bulkMarkDelivered(allOrders),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                              ),
                              child: const Text('Mark delivered'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed:
                                  allPaid ? null : () => _bulkMarkPaid(allOrders),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                              ),
                              child: const Text('Mark paid'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            : const SizedBox.shrink(),
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
                  daysWithOrders: daysWithOrders,
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
                child: _buildEmptyState(
                  hasAnyOrders: !noOrdersYet,
                  daysWithOrders: daysWithOrders,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                sliver: Builder(
                  builder: (context) {
                    final widgets = _buildGroupedOrderWidgets(
                      filteredOrders,
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
      ),
    );
  }

  List<Widget> _buildGroupedOrderWidgets(
    List<Order> filteredOrders,
  ) {
    final todayKey = _calendarDay(DateTime.now());
    final groups = <DateTime, List<Order>>{};

    for (final order in filteredOrders) {
      final normalized = _calendarDay(order.orderDate);
      (groups[normalized] ??= []).add(order);
    }

    final sortedDays = groups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];

    // When a range is active, lead with a summary of the whole span.
    if (_selectedRange != null) {
      final rangeTotal =
          filteredOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
      widgets.add(
        _RangeSummaryHeader(
          label:
              '${DateFormat('d MMM').format(_selectedRange!.start)}'
              ' – '
              '${DateFormat('d MMM').format(_selectedRange!.end)}',
          count: filteredOrders.length,
          total: rangeTotal,
        ),
      );
    }

    for (final day in sortedDays) {
      final orders = groups[day]!..sort(
        (a, b) => compareOrdersByDate(a, b),
      );
      final dayTotal = orders.fold(0.0, (sum, o) => sum + o.totalAmount);
      widgets.add(
        _DateSectionHeader(
          title: _formatBusinessDaySection(day, todayKey),
          count: orders.length,
          dayTotal: dayTotal,
        ),
      );
      for (final o in orders) {
        widgets.add(OrderCard(
          key: ValueKey(o.id),
          order: o,
          siblingOrders: orders,
          isSelected: _selectedIds.contains(o.id),
          onToggleSelect: _isSelecting
              ? () => setState(() {
                    if (_selectedIds.contains(o.id)) {
                      _selectedIds.remove(o.id);
                    } else {
                      _selectedIds.add(o.id);
                    }
                  })
              : null,
          onEnterSelectMode: _isSelecting
              ? () => setState(() => _selectedIds.add(o.id))
              : () {
                  HapticFeedback.mediumImpact();
                  setState(() => _selectedIds.add(o.id));
                },
        ));
      }
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Widget _buildFilters(
    List<DeliveryRoute> routes,
    List<String> availableRouteIds, {
    required bool routesLoaded,
    required Set<DateTime> daysWithOrders,
  }) {
    final hasRouteFilter = availableRouteIds.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: _selectedRange != null
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          // Clearing a range returns to today's single day.
                          _selectedRange = null;
                          _selectedDate = _calendarDay(DateTime.now());
                        }),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${DateFormat('d MMM').format(_selectedRange!.start)}'
                              ' – '
                              '${DateFormat('d MMM').format(_selectedRange!.end)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      )
                    : _selectedDate != null
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _selectedDate = null),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('EEE, d MMM').format(_selectedDate!),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      )
                    : Text(
                        DateFormat('MMMM yyyy').format(
                          _visibleLeadDate ?? DateTime.now(),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
              IconButton(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_rounded),
                color: AppColors.primary,
                visualDensity: VisualDensity.compact,
                tooltip: 'Pick a date range',
              ),
            ],
          ),
        ),
        SizedBox(
          height: _kDayStripHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final now = DateTime.now();
              // "Today" on the strip is the calendar day, matching how orders
              // are grouped and the default selection, so the highlighted cell
              // always lines up with where today's orders appear.
              final todayKey = _calendarDay(now);
              final cellWidth = constraints.maxWidth / 7;
              _dayCellWidth = cellWidth;
              // Frame the strip on the current week the first time we know the
              // available width.
              if (!_dayStripPositioned) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted ||
                      _dayStripPositioned ||
                      !_dayScrollController.hasClients) {
                    return;
                  }
                  _dayScrollController.jumpTo(
                    initialDayStripIndex(now) * cellWidth,
                  );
                  _dayStripPositioned = true;
                  _updateVisibleLeadDate();
                });
              }
              return Stack(
                alignment: Alignment.center,
                children: [
                  NotificationListener<ScrollEndNotification>(
                    onNotification: (_) {
                      _updateVisibleLeadDate();
                      return false;
                    },
                    child: ListView.builder(
                      controller: _dayScrollController,
                      scrollDirection: Axis.horizontal,
                      itemExtent: cellWidth,
                      physics: const BouncingScrollPhysics(),
                      itemBuilder: (context, index) {
                        final day = dayForIndex(now, index);
                        final isSelected = _selectedDate == day;
                        return Center(
                          child: _DayCell(
                            day: day,
                            isToday: day == todayKey,
                            isSelected: isSelected,
                            isPast: day.isBefore(todayKey),
                            hasOrders: daysWithOrders.contains(day),
                            onTap: () => setState(() {
                              // Tapping a single day exits range mode.
                              _selectedRange = null;
                              _selectedDate = isSelected ? null : day;
                            }),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    left: 2,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: AppColors.textLight.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    child: IgnorePointer(
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.textLight.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _searchQuery.trim().isNotEmpty
              ? Padding(
                  key: const ValueKey('search-chip'),
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Row(
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width - 32,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _searchQuery.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchController.clear();
                                });
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
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
      if (res.clearAll) {
        _selectedDate = null;
        _selectedRange = null;
      }
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

  /// Nearest day that has orders relative to [from]: prefer the most recent day
  /// on or before [from], otherwise the soonest day after it.
  DateTime? _nearestDayWithOrders(DateTime from, Set<DateTime> days) {
    if (days.isEmpty) return null;
    final sorted = days.toList()..sort();
    DateTime? before;
    DateTime? after;
    for (final d in sorted) {
      if (!d.isAfter(from)) {
        before = d;
      } else {
        after ??= d;
      }
    }
    return before ?? after;
  }

  Widget _buildEmptyState({
    required bool hasAnyOrders,
    required Set<DateTime> daysWithOrders,
  }) {
    // The account has no orders at all.
    if (!hasAnyOrders) {
      return DeliveroEmptyState(
        title: 'No orders yet',
        subtitle: 'Create your first order to see it here.',
        icon: Icons.receipt_long_rounded,
        actionLabel: 'Create order',
        onActionPressed: () => context.push('/owner/orders/create'),
      );
    }

    // A future day is selected and empty — offer to generate that day's daily
    // orders (after resolving today's), or add one manually.
    final today = _calendarDay(DateTime.now());
    if (_selectedRange == null &&
        _selectedDate != null &&
        _selectedDate!.isAfter(today) &&
        _searchQuery.trim().isEmpty) {
      return _buildFutureDayEmptyState(_selectedDate!);
    }

    // A specific day/range is selected and empty, but orders exist on other
    // days — point the owner to the nearest day that has orders.
    final hasDateFilter = _selectedDate != null || _selectedRange != null;
    if (hasDateFilter &&
        _searchQuery.trim().isEmpty &&
        daysWithOrders.isNotEmpty) {
      final from = _selectedRange?.end ?? _selectedDate!;
      final nearest = _nearestDayWithOrders(from, daysWithOrders);
      if (nearest != null) {
        final label = _selectedRange != null
            ? '${DateFormat('d MMM').format(_selectedRange!.start)}'
                  ' – ${DateFormat('d MMM').format(_selectedRange!.end)}'
            : DateFormat('EEE, d MMM').format(_selectedDate!);
        return DeliveroEmptyState(
          title: 'No orders for $label',
          subtitle:
              'Your nearest orders are on ${DateFormat('EEE, d MMM').format(nearest)}.',
          icon: Icons.event_busy_rounded,
          actionLabel: 'View ${DateFormat('d MMM').format(nearest)}',
          onActionPressed: () {
            setState(() {
              _selectedRange = null;
              _selectedDate = nearest;
            });
            if (_dayScrollController.hasClients && _dayCellWidth > 0) {
              _dayScrollController.animateTo(
                dayIndexForDate(DateTime.now(), nearest) * _dayCellWidth,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          },
        );
      }
    }

    // Empty because of payment/status/search filters.
    return DeliveroEmptyState(
      title: 'No transactions found',
      subtitle: 'Try adjusting your filters or search terms',
      icon: Icons.receipt_long_rounded,
    );
  }

  /// Empty state for a selected future day: generate that day's daily orders or
  /// add one manually.
  Widget _buildFutureDayEmptyState(DateTime day) {
    final dateLabel = DateFormat('EEE, d MMM').format(day);
    final shortLabel = DateFormat('d MMM').format(day);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No orders for $dateLabel yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Generate this day's daily orders from your latest run, or add one manually.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _generateForSelectedDay(day),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: Text('Generate orders for $shortLabel'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/owner/orders/create'),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add order'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Generate the selected day's daily orders. First prompts the owner to
  /// resolve today's not-yet-delivered orders (so nothing carries forward by
  /// mistake), then creates the day's run.
  Future<void> _generateForSelectedDay(DateTime day) async {
    final factoryId = ref.read(authProvider).user?.factoryId;
    if (factoryId == null || factoryId.isEmpty) return;
    final rolloverHour = ref.read(orderRolloverHourProvider);
    final orders = ref.read(ordersProvider);
    final today = _calendarDay(DateTime.now());
    final dateLabel = DateFormat('d MMM').format(day);

    // Resolve today's not-yet-delivered orders before creating the next day's.
    final unresolved = findUnresolvedSourceOrders(
      orders: orders,
      sourceBusinessDay: today,
      rolloverHour: rolloverHour,
    );
    if (unresolved.isNotEmpty) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => UnresolvedOrdersSheet(
          orderIds: unresolved.map((o) => o.id).toList(),
          title: "Update today's orders first",
          subtitle:
              "Mark each as delivered or cancelled before generating $dateLabel's orders.",
          doneLabel: 'Done — generate $dateLabel',
        ),
      );
    }
    if (!mounted) return;

    final result = await ref
        .read(ordersProvider.notifier)
        .runDailyGenerationForDay(factoryId, day);
    if (!mounted) return;

    final msg = switch (result.createdCount) {
      0 => 'No daily orders to generate for $dateLabel',
      1 => '1 order generated for $dateLabel',
      _ => '${result.createdCount} orders generated for $dateLabel',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
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

class _DayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final bool isPast;
  final bool hasOrders;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.isPast,
    required this.hasOrders,
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
          // Dot marks days that have orders, so the run is visible at a glance
          // without scrolling into each day. Today stays distinct via its
          // tinted cell above.
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: hasOrders
                  ? (isSelected ? Colors.white : AppColors.primary)
                  : Colors.transparent,
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
  final double dayTotal;
  const _DateSectionHeader({
    required this.title,
    required this.count,
    required this.dayTotal,
  });

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
              '${formatRupee(dayTotal)} · $count ${count == 1 ? 'Order' : 'Orders'}',
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

/// Summary card shown at the top of the list when a date range is active.
class _RangeSummaryHeader extends StatelessWidget {
  final String label;
  final int count;
  final double total;
  const _RangeSummaryHeader({
    required this.label,
    required this.count,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 4, 2, 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.date_range_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${formatRupee(total)} · $count ${count == 1 ? 'Order' : 'Orders'}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
