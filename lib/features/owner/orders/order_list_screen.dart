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
import '../../../core/orders/day_strip_math.dart';
import '../../../core/orders/order_sort.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/order_week_day_strip.dart';
import '../../../core/utils/route_refs.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../data/models/order.dart';
import '../../../data/models/delivery_route.dart';
import 'production_summary_sheet.dart';
import 'unresolved_orders_sheet.dart';
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
  // When set, the list shows every order whose day falls in this inclusive
  // range (grouped by day). Mutually exclusive with [_selectedDate].
  DateTimeRange? _selectedRange;
  bool _selectedDateInitialized = false;
  Timer? _highlightClearTimer;
  final ScrollController _dayScrollController = ScrollController();
  double _dayCellWidth = 0;
  DateTime? _visibleLeadDate;

  Set<String> _selectedIds = {};
  bool get _isSelecting => _selectedIds.isNotEmpty;

  String _formatBusinessDaySection(DateTime dayKey, DateTime todayKey) {
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
        .where(
          (o) =>
              _selectedIds.contains(o.id) && o.status != OrderStatus.delivered,
        )
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
          SnackBar(
            content: Text('${targets.length} orders marked as delivered'),
          ),
        );
      }
    }
  }

  Future<void> _bulkMarkPaid(List<Order> allOrders) async {
    final now = DateTime.now();
    final targets = allOrders
        .where(
          (o) =>
              _selectedIds.contains(o.id) &&
              o.paymentStatus != PaymentStatus.paid,
        )
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

  DateTime _calendarDay(DateTime value) => calendarDayKey(value);

  DateTime get _todayKey => _calendarDay(DateTime.now());

  void _scrollDayStripTo(DateTime day) {
    if (!_dayScrollController.hasClients || _dayCellWidth <= 0) return;
    _dayScrollController.animateTo(
      dayIndexForDate(DateTime.now(), day) * _dayCellWidth,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  bool get _hasSecondaryFilters =>
      _searchQuery.trim().isNotEmpty ||
      _selectedPaymentStatus != null ||
      _selectedOrderStatus != null ||
      _selectedRouteId != null;

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
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _productionDay = _calendarDay(picked));
    }
  }

  Future<void> _pickSingleDay() async {
    final initial = _selectedDate ?? _calendarDay(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      final day = _calendarDay(picked);
      setState(() {
        _selectedRange = null;
        _selectedDate = day;
      });
      _scrollDayStripTo(day);
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
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
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
        matchesDay =
            !orderDay.isBefore(_selectedRange!.start) &&
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

    // Hide FAB only on true empty states (no orders yet, or a date filter
    // with no matches). Keep FAB visible when payment/status/route/search
    // filters zero out results but other orders still exist.
    final viewIsEmpty =
        filteredOrders.isEmpty && (noOrdersYet || !_hasSecondaryFilters);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(ordersViewIsEmptyProvider.notifier).set(viewIsEmpty);
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _isSelecting) {
            setState(() => _selectedIds = {});
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.success,
          body: Column(
            children: [
              ColoredBox(
                color: AppColors.success,
                child: SafeArea(
                  bottom: false,
                  child: _OrdersPurpleHeader(
                    isSelecting: _isSelecting,
                    selectedCount: _selectedIds.length,
                    onCloseSelection: () => setState(() => _selectedIds = {}),
                    showProductionAction: !noOrdersYet,
                    onProduction: () => _openProductionSummary(
                      orders: orders,
                      routes: routes,
                      productionDay: productionDay,
                      rolloverHour: rolloverHour,
                    ),
                    onSearch: () => _openSearchSheet(context),
                    onFilter: () => _showFiltersSheet(context),
                  ),
                ),
              ),
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppColors.backgroundPrimary,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      if (!noOrdersYet)
                        _buildFilters(
                          routes,
                          availableRouteIds,
                          routesLoaded: routesLoaded,
                          daysWithOrders: daysWithOrders,
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: () =>
                              ref.read(ordersProvider.notifier).refresh(),
                          child: _buildOrdersBody(
                            ordersLoaded: ordersLoaded,
                            orders: orders,
                            noOrdersYet: noOrdersYet,
                            filteredOrders: filteredOrders,
                            daysWithOrders: daysWithOrders,
                          ),
                        ),
                      ),
                      if (_isSelecting)
                        _BulkSelectionBar(
                          selectedIds: _selectedIds,
                          onMarkDelivered: () =>
                              _bulkMarkDelivered(ref.read(ordersProvider)),
                          onMarkPaid: () =>
                              _bulkMarkPaid(ref.read(ordersProvider)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersBody({
    required bool ordersLoaded,
    required List<Order> orders,
    required bool noOrdersYet,
    required List<Order> filteredOrders,
    required Set<DateTime> daysWithOrders,
  }) {
    if (!ordersLoaded && orders.isEmpty) {
      return const CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (filteredOrders.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(
              hasAnyOrders: !noOrdersYet,
              daysWithOrders: daysWithOrders,
            ),
          ),
        ],
      );
    }

    final widgets = _buildGroupedOrderWidgets(filteredOrders);
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => widgets[index],
              childCount: widgets.length,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGroupedOrderWidgets(List<Order> filteredOrders) {
    final todayKey = _calendarDay(DateTime.now());
    final groups = <DateTime, List<Order>>{};

    for (final order in filteredOrders) {
      final normalized = _calendarDay(order.orderDate);
      (groups[normalized] ??= []).add(order);
    }

    final sortedDays = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];

    // When a range is active, lead with a summary of the whole span.
    if (_selectedRange != null) {
      final rangeTotal = filteredOrders.fold(
        0.0,
        (sum, o) => sum + o.totalAmount,
      );
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
      final orders = groups[day]!..sort((a, b) => compareOrdersByDate(a, b));
      final dayTotal = orders.fold(0.0, (sum, o) => sum + o.totalAmount);
      widgets.add(
        _DateSectionHeader(
          title: _formatBusinessDaySection(day, todayKey),
          count: orders.length,
          dayTotal: dayTotal,
        ),
      );
      for (final o in orders) {
        widgets.add(
          OrderCard(
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
          ),
        );
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
    final showRouteFilters = availableRouteIds.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 0),
          child: Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _selectedRange != null
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          _selectedRange = null;
                          _selectedDate = _todayKey;
                        }),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                '${DateFormat('EEE, d MMM').format(_selectedRange!.start)}'
                                ' – '
                                '${DateFormat('EEE, d MMM').format(_selectedRange!.end)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      )
                    : _selectedDate != null
                    ? GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _pickSingleDay,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('EEE, d MMM').format(_selectedDate!),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      )
                    : Text(
                        DateFormat(
                          'MMMM yyyy',
                        ).format(_visibleLeadDate ?? DateTime.now()),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
              Material(
                color: AppColors.primaryLighter,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _pickRange,
                  borderRadius: BorderRadius.circular(12),
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        OrderWeekDayStrip(
          scrollController: _dayScrollController,
          selectedDate: _searchQuery.trim().isEmpty ? _selectedDate : null,
          daysWithOrders: daysWithOrders,
          onCellWidthChanged: (w) => _dayCellWidth = w,
          onVisibleLeadDateChanged: (lead) {
            if (lead != _visibleLeadDate) {
              setState(() => _visibleLeadDate = lead);
            }
          },
          onDayTap: (day, wasSelected) {
            if (wasSelected) return;
            setState(() {
              _selectedRange = null;
              _selectedDate = day;
            });
          },
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                                '${_searchQuery.trim()} · all dates',
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
        if (showRouteFilters) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
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
                  const SizedBox(width: 8),
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
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildRouteChip(
                            routeId,
                            route?.name ?? routeId,
                            routesLoaded: routesLoaded,
                          ),
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
    final isAllRoutes = routeId == null;
    return InkWell(
      onTap: (isLoading || (!routesLoaded && routeId != null))
          ? null
          : () {
              setState(() {
                _selectedRouteId = isSelected ? null : routeId;
              });
            },
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAllRoutes ? Icons.map_outlined : Icons.location_on_outlined,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : isLoading || (!routesLoaded && routeId != null)
                  ? AppColors.textDisabled
                  : AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : isLoading || (!routesLoaded && routeId != null)
                    ? AppColors.textDisabled
                    : AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ],
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
        _selectedRange = null;
        _selectedDate = _todayKey;
      }
    });
    if (res.clearAll) {
      _scrollDayStripTo(_todayKey);
    }
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

    // Today is selected and empty — offer to generate today's daily orders.
    if (_selectedRange == null &&
        _selectedDate == today &&
        _searchQuery.trim().isEmpty) {
      return DeliveroEmptyState(
        title: 'No orders for today',
        subtitle:
            "Generate today's daily orders from your recurring customers.",
        icon: Icons.event_busy_rounded,
        actionLabel: "Generate today's orders",
        onActionPressed: () => _generateForSelectedDay(today),
      );
    }

    // A date range or other single day is selected and empty.
    final hasDateFilter = _selectedDate != null || _selectedRange != null;
    if (hasDateFilter && _searchQuery.trim().isEmpty) {
      final label = _selectedRange != null
          ? '${DateFormat('d MMM').format(_selectedRange!.start)}'
                ' – ${DateFormat('d MMM').format(_selectedRange!.end)}'
          : DateFormat('EEE, d MMM').format(_selectedDate!);
      return DeliveroEmptyState(
        title: 'No orders for $label',
        subtitle: 'Try another date or create an order manually.',
        icon: Icons.event_busy_rounded,
        actionLabel: 'Create order',
        onActionPressed: () => context.push('/owner/orders/create'),
      );
    }

    // Empty because of payment/status/route/search filters.
    if (_hasSecondaryFilters) {
      return DeliveroEmptyState(
        title: 'No matching orders',
        subtitle: 'Try adjusting your filters or search terms.',
        icon: Icons.receipt_long_rounded,
        actionLabel: 'Clear filters',
        onActionPressed: () {
          setState(() {
            _searchQuery = '';
            _searchController.clear();
            _selectedPaymentStatus = null;
            _selectedOrderStatus = null;
            _selectedRouteId = null;
            _selectedRange = null;
            _selectedDate = _todayKey;
          });
          _scrollDayStripTo(_todayKey);
        },
      );
    }

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
        builder: (sheetContext) => UnresolvedOrdersSheet(
          orderIds: unresolved.map((o) => o.id).toList(),
          title: "Update today's orders first",
          subtitle:
              "Mark each as delivered or cancelled before generating $dateLabel's orders.",
          doneLabel: 'Done — generate $dateLabel',
        ),
      );
      if (!mounted) return;

      final stillUnresolved = findUnresolvedSourceOrders(
        orders: ref.read(ordersProvider),
        sourceBusinessDay: today,
        rolloverHour: rolloverHour,
      );
      if (stillUnresolved.isNotEmpty) return;
    }

    final result = await ref
        .read(ordersProvider.notifier)
        .runDailyGenerationForDay(factoryId, day);
    if (!mounted) return;

    final msg = switch (result.createdCount) {
      0 => 'No daily orders to generate for $dateLabel',
      1 => '1 order generated for $dateLabel',
      _ => '${result.createdCount} orders generated for $dateLabel',
    };
    if (result.createdCount > 0) {
      setState(() {
        _selectedRange = null;
        _selectedDate = _calendarDay(day);
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class _BulkSelectionBar extends ConsumerWidget {
  final Set<String> selectedIds;
  final VoidCallback onMarkDelivered;
  final VoidCallback onMarkPaid;

  const _BulkSelectionBar({
    required this.selectedIds,
    required this.onMarkDelivered,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allOrders = ref.watch(ordersProvider);
    final selectedOrders = allOrders
        .where((o) => selectedIds.contains(o.id))
        .toList();
    final allDelivered =
        selectedOrders.isEmpty ||
        selectedOrders.every((o) => o.status == OrderStatus.delivered);
    final allPaid =
        selectedOrders.isEmpty ||
        selectedOrders.every((o) => o.paymentStatus == PaymentStatus.paid);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: allDelivered ? null : onMarkDelivered,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                child: const Text('Mark delivered'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: allPaid ? null : onMarkPaid,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('Mark paid'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersPurpleHeader extends StatelessWidget {
  final bool isSelecting;
  final int selectedCount;
  final VoidCallback onCloseSelection;
  final bool showProductionAction;
  final VoidCallback onProduction;
  final VoidCallback onSearch;
  final VoidCallback onFilter;

  const _OrdersPurpleHeader({
    required this.isSelecting,
    required this.selectedCount,
    required this.onCloseSelection,
    required this.showProductionAction,
    required this.onProduction,
    required this.onSearch,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 20),
      child: Row(
        children: [
          if (isSelecting)
            IconButton(
              onPressed: onCloseSelection,
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          Expanded(
            child: Text(
              isSelecting ? '$selectedCount selected' : 'Orders',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ),
          if (!isSelecting) ...[
            if (showProductionAction)
              _HeaderActionButton(
                icon: Icons.inventory_2_outlined,
                tooltip: 'Production list',
                onPressed: onProduction,
              ),
            _HeaderActionButton(
              icon: Icons.search_rounded,
              tooltip: 'Search',
              onPressed: onSearch,
            ),
            _HeaderActionButton(
              icon: Icons.tune_rounded,
              tooltip: 'Filter',
              onPressed: onFilter,
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
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
