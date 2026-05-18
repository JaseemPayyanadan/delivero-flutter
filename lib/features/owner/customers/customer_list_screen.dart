import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import '../../../app/providers.dart';
import '../../../app/reports_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/delivery_route.dart';
import '../../../data/models/order.dart';

// ignore_for_file: unnecessary_underscores, unused_element_parameter, unused_local_variable

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedRouteId;
  late AnimationController _arrowController;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _arrowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final customersLoaded = ref.watch(customersLoadedProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    final routes = ref.watch(routesProvider);
    final orders = ref.watch(ordersProvider);
    final reports = ref.watch(reportsProvider);

    final Map<String, List<Order>> ordersByCustomer = {};
    for (final order in orders) {
      final id = order.customerId;
      if (id.isEmpty) continue;
      (ordersByCustomer[id] ??= []).add(order);
    }

    final Map<String, DeliveryRoute> routesById = {
      for (final r in routes) r.id: r,
    };

    DeliveryRoute? routeForCustomer(Customer c) {
      if (c.assignedRoute == null) return null;
      final direct = routesById[c.assignedRoute];
      if (direct != null) return direct;
      return routes.firstWhereOrNull((r) => r.name == c.assignedRoute);
    }

    String routeNameForCustomer(Customer c) {
      final r = routeForCustomer(c);
      if (!routesLoaded && routes.isEmpty) return 'Loading route…';
      return r?.name ??
          (c.assignedRoute?.trim().isNotEmpty == true
              ? c.assignedRoute!.trim()
              : 'No route');
    }

    String? routeIdForCustomer(Customer c) {
      final r = routeForCustomer(c);
      return r?.id;
    }

    final availableRouteIds =
        customers.map(routeIdForCustomer).whereType<String>().toSet().toList()
          ..sort((a, b) {
            final an = routesById[a]?.name ?? '';
            final bn = routesById[b]?.name ?? '';
            return an.compareTo(bn);
          });
    final showRouteFilterButton = availableRouteIds.length > 1;

    final filteredCustomers = customers.where((customer) {
      final q = _searchQuery.toLowerCase().trim();
      final matchesSearch = q.isEmpty
          ? true
          : customer.name.toLowerCase().contains(q) ||
                (customer.ownerName?.toLowerCase().contains(q) ?? false) ||
                customer.phone.contains(_searchQuery.trim()) ||
                customer.email.toLowerCase().contains(q) ||
                customer.address.toLowerCase().contains(q) ||
                customer.area.toLowerCase().contains(q);

      final matchesRoute = switch (_selectedRouteId) {
        null => true,
        _ =>
          customer.assignedRoute == _selectedRouteId ||
              routeIdForCustomer(customer) == _selectedRouteId,
      };

      return matchesSearch && matchesRoute;
    }).toList();

    filteredCustomers.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final bool noCustomersYet = customers.isEmpty;
    int totalOrdersCount = 0;
    if (!noCustomersYet) {
      for (final customer in filteredCustomers) {
        final customerOrders = ordersByCustomer[customer.id] ?? const [];
        totalOrdersCount += customerOrders.length;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Customers',
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => _openSearchSheet(context),
            icon: const Icon(
              Icons.search_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          if (showRouteFilterButton)
            IconButton(
              tooltip: 'Filter',
              onPressed: () => _openRouteFilterSheet(
                context,
                availableRouteIds: availableRouteIds,
                routesById: routesById,
                routesLoaded: routesLoaded,
                routes: routes,
              ),
              icon: const Icon(
                Icons.tune_rounded,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          try {
            HapticFeedback.lightImpact();
          } catch (_) {}
          context.push('/owner/customers/add');
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 10,
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(customersProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            if (!noCustomersYet && availableRouteIds.length > 1)
              SliverToBoxAdapter(
                child: _RouteChipsRow(
                  selectedRouteId: _selectedRouteId,
                  availableRouteIds: availableRouteIds,
                  routesById: routesById,
                  routesLoaded: routesLoaded,
                  routes: routes,
                  onChipTapped: _onRouteChipTapped,
                ),
              ),
            if (!customersLoaded && customers.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredCustomers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(
                  title: customers.isEmpty
                      ? 'No customers yet'
                      : 'No matching customers',
                  subtitle: customers.isEmpty
                      ? 'Add a customer to start taking orders and assigning routes.'
                      : 'Try adjusting your filters or search terms.',
                  icon: customers.isEmpty
                      ? Icons.business_center_outlined
                      : Icons.search_off_outlined,
                  actionLabel: customers.isEmpty
                      ? 'Add Customer'
                      : 'Clear search',
                  onAction: customers.isEmpty
                      ? () => context.push('/owner/customers/add')
                      : () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _selectedRouteId = null;
                          });
                        },
                ),
              )
            else
              ..._buildGroupedCustomerSlivers(
                context,
                filteredCustomers: filteredCustomers,
                routeNameForCustomer: routeNameForCustomer,
                routeIdForCustomer: routeIdForCustomer,
                ordersByCustomer: ordersByCustomer,
                reports: reports,
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Future<void> _openSearchSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SearchSheet(
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

  Future<void> _openRouteFilterSheet(
    BuildContext context, {
    required List<String> availableRouteIds,
    required Map<String, DeliveryRoute> routesById,
    required bool routesLoaded,
    required List<DeliveryRoute> routes,
  }) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _RouteFilterSheet(
          selectedRouteId: _selectedRouteId,
          availableRouteIds: availableRouteIds,
          routesById: routesById,
          routesLoaded: routesLoaded,
          routes: routes,
        );
      },
    );
    if (picked == null) return;
    setState(() => _selectedRouteId = picked.isEmpty ? null : picked);
  }

  void _onRouteChipTapped(String? chipId) {
    setState(() {
      if (chipId == 'loading') return;
      _selectedRouteId = _selectedRouteId == chipId ? null : chipId;
    });
  }

  Future<void> _openAssignRouteSheet(
    BuildContext context,
    Customer customer,
  ) async {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    final messenger = ScaffoldMessenger.of(context);
    final routes = ref.read(routesProvider);
    final picked = await showModalBottomSheet<DeliveryRoute>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) =>
          _AssignRouteSheet(customerName: customer.name, routes: routes),
    );
    if (picked == null || !mounted) return;

    final updated = Customer(
      id: customer.id,
      factoryId: customer.factoryId,
      name: customer.name,
      ownerName: customer.ownerName,
      email: customer.email,
      phone: customer.phone,
      address: customer.address,
      area: customer.area.isEmpty ? picked.area : customer.area,
      isActive: customer.isActive,
      discountPercentage: customer.discountPercentage,
      assignedRoute: picked.name,
      products: customer.products,
      createdAt: customer.createdAt,
      updatedAt: DateTime.now(),
    );
    ref.read(customersProvider.notifier).updateCustomer(updated);

    messenger.showSnackBar(
      SnackBar(
        content: Text('${customer.name} assigned to ${picked.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Widget> _buildGroupedCustomerSlivers(
    BuildContext context, {
    required List<Customer> filteredCustomers,
    required String Function(Customer) routeNameForCustomer,
    required String? Function(Customer) routeIdForCustomer,
    required Map<String, List<Order>> ordersByCustomer,
    required ReportsData reports,
  }) {
    final Map<String, List<Customer>> grouped = {};
    for (final c in filteredCustomers) {
      final key = routeNameForCustomer(c);
      (grouped[key] ??= []).add(c);
    }
    final groupKeys = grouped.keys.toList()..sort();

    final slivers = <Widget>[];
    for (final key in groupKeys) {
      final items = grouped[key]!
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: _GroupHeader(title: key, count: items.length),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final customer = items[index];
              final customerOrders = ordersByCustomer[customer.id] ?? const [];
              customerOrders.sortedBy((o) => o.orderDate);

              final latest = customerOrders.isEmpty
                  ? null
                  : (customerOrders
                          ..sort((a, b) => b.orderDate.compareTo(a.orderDate)))
                        .first;

              final scheduleLabel =
                  customerOrders.any((o) => o.orderType == OrderType.daily)
                  ? 'Daily'
                  : _scheduleLabelForCustomer(customerOrders);

              final paymentStatus = latest?.paymentStatus;
              final customerReport = reports.customerRevenue[customer.name];
              final ltv = customerReport?.revenue ?? 0;

              double pendingAmount = 0;
              for (final o in customerOrders) {
                switch (o.paymentStatus) {
                  case PaymentStatus.unpaid:
                    pendingAmount += o.totalAmount;
                    break;
                  case PaymentStatus.partial:
                    pendingAmount += (o.totalAmount - (o.amountPaid ?? 0))
                        .clamp(0, double.infinity);
                    break;
                  case PaymentStatus.paid:
                  case null:
                    break;
                }
              }
              final hasPending = pendingAmount > 0.004;
              final hasRoute = routeIdForCustomer(customer) != null;

              return _CustomerListCard(
                customer: customer,
                phone: customer.phone,
                paymentStatus: paymentStatus,
                hasPending: hasPending,
                hasRoute: hasRoute,
                scheduleLabel: scheduleLabel,
                onTap: () {
                  try {
                    HapticFeedback.selectionClick();
                  } catch (_) {}
                  context.push('/owner/customers/${customer.id}');
                },
                onAssignRoute: () => _openAssignRouteSheet(context, customer),
              );
            },
          ),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 4)));
    }
    return slivers;
  }

  String? _scheduleLabelForCustomer(List<Order> customerOrders) {
    if (customerOrders.isEmpty) return null;
    if (customerOrders.any((o) => o.orderType == OrderType.oneTime)) {
      return 'One-time';
    }
    if (customerOrders.any((o) => o.orderType == OrderType.special)) {
      return 'Special';
    }
    return null;
  }

  // Customer list intentionally avoids quick actions (call, etc.)
  // to reduce clutter and mis-taps. Details page has contact actions.

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
    bool showArrow = false,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return DeliveroEmptyState(
      title: title,
      subtitle: subtitle,
      icon: icon,
      actionLabel: actionLabel,
      onActionPressed: onAction,
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;
  const _GroupHeader({required this.title, required this.count});

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
              '$count ${count == 1 ? 'Customer' : 'Customers'}',
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

class _CustomerListCard extends StatelessWidget {
  final Customer customer;
  final String phone;
  final PaymentStatus? paymentStatus;
  final bool hasPending;
  final bool hasRoute;
  final String? scheduleLabel;
  final VoidCallback onTap;
  final VoidCallback onAssignRoute;

  const _CustomerListCard({
    required this.customer,
    required this.phone,
    required this.paymentStatus,
    required this.hasPending,
    required this.hasRoute,
    required this.scheduleLabel,
    required this.onTap,
    required this.onAssignRoute,
  });

  @override
  Widget build(BuildContext context) {
    final payment = _PaymentPill.from(paymentStatus);
    final hasScheduleInfo = scheduleLabel != null;

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.45,
                            ),
                          ),
                        ),
                        if (hasPending) ...[
                          const SizedBox(width: 10),
                          payment.pill,
                        ],
                        const SizedBox(width: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textLight.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                    if (phone.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 15,
                          color: hasScheduleInfo
                              ? AppColors.primary
                              : AppColors.textLight,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            scheduleLabel ?? 'No orders yet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: hasScheduleInfo
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              fontSize: 12,
                              color: hasScheduleInfo
                                  ? AppColors.textSecondary
                                  : AppColors.textLight,
                            ),
                          ),
                        ),
                        if (!hasRoute)
                          TextButton.icon(
                            onPressed: onAssignRoute,
                            icon: const Icon(
                              Icons.alt_route_rounded,
                              size: 16,
                            ),
                            label: const Text(
                              'Assign route',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.08,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentPill {
  final _Pill pill;
  const _PaymentPill._(this.pill);

  factory _PaymentPill.from(PaymentStatus? status) {
    return switch (status) {
      PaymentStatus.paid => const _PaymentPill._(
        _Pill(
          label: 'PAID',
          fg: AppColors.success,
          bg: AppColors.successLighter,
          compact: true,
        ),
      ),
      PaymentStatus.partial => const _PaymentPill._(
        _Pill(
          label: 'PARTIAL',
          fg: AppColors.warning,
          bg: AppColors.warningLighter,
          compact: true,
        ),
      ),
      PaymentStatus.unpaid => const _PaymentPill._(
        _Pill(
          label: 'UNPAID',
          fg: AppColors.error,
          bg: AppColors.errorLighter,
          compact: true,
        ),
      ),
      _ => const _PaymentPill._(
        _Pill(
          label: 'UNPAID',
          fg: AppColors.error,
          bg: AppColors.errorLighter,
          compact: true,
        ),
      ),
    };
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final bool isUppercase;
  final bool compact;

  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.isUppercase = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: compact ? 0.8 : 0.68),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: compact ? 0.14 : 0.18)),
      ),
      child: Text(
        isUppercase ? label.toUpperCase() : label,
        style: TextStyle(
          fontSize: compact ? 11 : 10,
          fontWeight: FontWeight.w800,
          height: compact ? 1.1 : null,
          color: fg,
          letterSpacing: isUppercase ? (compact ? 0.5 : 0.8) : -0.2,
        ),
      ),
    );
  }
}

class _RouteChipsRow extends StatelessWidget {
  final String? selectedRouteId;
  final List<String> availableRouteIds;
  final Map<String, DeliveryRoute> routesById;
  final bool routesLoaded;
  final List<DeliveryRoute> routes;
  final void Function(String? chipId) onChipTapped;

  const _RouteChipsRow({
    required this.selectedRouteId,
    required this.availableRouteIds,
    required this.routesById,
    required this.routesLoaded,
    required this.routes,
    required this.onChipTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _CustomerRouteChip(
              label: 'All Routes',
              routeId: null,
              selectedRouteId: selectedRouteId,
              routesLoaded: routesLoaded,
              onChipTapped: onChipTapped,
            ),
            if (!routesLoaded && routes.isEmpty)
              _CustomerRouteChip(
                label: 'Loading…',
                routeId: 'loading',
                selectedRouteId: selectedRouteId,
                routesLoaded: routesLoaded,
                onChipTapped: onChipTapped,
              )
            else
              ...availableRouteIds.map((id) {
                final name = routesById[id]?.name ?? 'Unknown';
                return _CustomerRouteChip(
                  label: name,
                  routeId: id,
                  selectedRouteId: selectedRouteId,
                  routesLoaded: routesLoaded,
                  onChipTapped: onChipTapped,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CustomerRouteChip extends StatelessWidget {
  final String label;
  final String? routeId;
  final String? selectedRouteId;
  final bool routesLoaded;
  final void Function(String? chipId) onChipTapped;

  const _CustomerRouteChip({
    required this.label,
    required this.routeId,
    required this.selectedRouteId,
    required this.routesLoaded,
    required this.onChipTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isLoading = routeId == 'loading';
    final isSelected = !isLoading && selectedRouteId == routeId;
    final tapLocked = isLoading || (!routesLoaded && routeId != null);
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: tapLocked ? null : () => onChipTapped(routeId),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : tapLocked
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
}

class _SearchSheet extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchSheet({
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
                    'Search customers',
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
                    hintText: 'Name, phone, email, or address…',
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

class _RouteFilterSheet extends StatelessWidget {
  final String? selectedRouteId;
  final List<String> availableRouteIds;
  final Map<String, DeliveryRoute> routesById;
  final bool routesLoaded;
  final List<DeliveryRoute> routes;

  const _RouteFilterSheet({
    required this.selectedRouteId,
    required this.availableRouteIds,
    required this.routesById,
    required this.routesLoaded,
    required this.routes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                    'Filter by route',
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
                    'Close',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              onTap: () => Navigator.pop(context, ''),
              title: const Text(
                'All Routes',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              trailing: selectedRouteId == null
                  ? const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                    )
                  : const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textLight,
                    ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            if (!routesLoaded && routes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Loading routes…',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: availableRouteIds.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, i) {
                    final id = availableRouteIds[i];
                    final name = routesById[id]?.name ?? 'Unknown Route';
                    final selected = selectedRouteId == id;
                    return ListTile(
                      onTap: () => Navigator.pop(context, id),
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            )
                          : const Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.textLight,
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
}

class _AssignRouteSheet extends StatelessWidget {
  final String customerName;
  final List<DeliveryRoute> routes;

  const _AssignRouteSheet({required this.customerName, required this.routes});

  @override
  Widget build(BuildContext context) {
    final sortedRoutes = [...routes]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Assign a route',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.textPrimary,
                letterSpacing: -0.45,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pick a route for $customerName',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (sortedRoutes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'No routes available yet.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/owner/routes');
                      },
                      icon: const Icon(Icons.add_road_rounded, size: 18),
                      label: const Text('Create a route'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sortedRoutes.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final route = sortedRoutes[index];
                    final area = route.area.trim();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.alt_route_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        route.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: area.isEmpty
                          ? null
                          : Text(
                              area,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textLight,
                      ),
                      onTap: () => Navigator.pop(context, route),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
