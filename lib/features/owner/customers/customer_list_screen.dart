import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import '../../../app/providers.dart';
import '../../../app/reports_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/primary_square_icon_button.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/delivery_route.dart';
import '../../../data/models/order.dart';

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
      return r?.name ?? (c.assignedRoute?.trim().isNotEmpty == true
          ? c.assignedRoute!.trim()
          : 'Unassigned');
    }

    String? routeIdForCustomer(Customer c) {
      final r = routeForCustomer(c);
      return r?.id;
    }

    final availableRouteIds = customers
        .map(routeIdForCustomer)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort((a, b) {
        final an = routesById[a]?.name ?? '';
        final bn = routesById[b]?.name ?? '';
        return an.compareTo(bn);
      });

    final filteredCustomers = customers.where((customer) {
      final matchesSearch =
          customer.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (customer.ownerName?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false) ||
          customer.phone.contains(_searchQuery) ||
          customer.address.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesRoute =
          _selectedRouteId == null ||
          customer.assignedRoute == _selectedRouteId ||
          routeIdForCustomer(customer) == _selectedRouteId;

      return matchesSearch && matchesRoute;
    }).toList();

    filteredCustomers.sort((a, b) => a.name.compareTo(b.name));

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
            icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
          ),
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
        onPressed: () => context.push('/owner/customers/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _RouteChipsRow(
                  selectedRouteId: _selectedRouteId,
                  availableRouteIds: availableRouteIds,
                  routesById: routesById,
                  routesLoaded: routesLoaded,
                  routes: routes,
                  onSelect: (id) => setState(() => _selectedRouteId = id),
                ),
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
                      : 'Nothing matches your search',
                  subtitle: customers.isEmpty
                      ? 'Add a customer to start taking orders and assigning routes.'
                      : 'Try a different search or pick another route.',
                  icon: customers.isEmpty
                      ? Icons.business_center_outlined
                      : Icons.search_off_outlined,
                  actionLabel: customers.isEmpty ? 'Add Customer' : 'Clear Search',
                  onAction: customers.isEmpty
                      ? () => context.push('/owner/customers/add')
                      : () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                ),
              )
            else ..._buildGroupedCustomerSlivers(
              context,
              filteredCustomers: filteredCustomers,
              routeNameForCustomer: routeNameForCustomer,
              ordersByCustomer: ordersByCustomer,
              reports: reports,
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  List<Widget> _buildGroupedCustomerSlivers(
    BuildContext context, {
    required List<Customer> filteredCustomers,
    required String Function(Customer) routeNameForCustomer,
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
      final items = grouped[key]!..sort((a, b) => a.name.compareTo(b.name));
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _GroupHeader(
              title: key,
              count: items.length,
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          sliver: SliverList.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final customer = items[index];
              final customerOrders = ordersByCustomer[customer.id] ?? const [];
              customerOrders.sortedBy((o) => o.orderDate);

              final latest = customerOrders.isEmpty
                  ? null
                  : (customerOrders..sort((a, b) => b.orderDate.compareTo(a.orderDate))).first;

              final scheduleLabel = customerOrders.any((o) => o.orderType == OrderType.daily)
                  ? 'Daily'
                  : (latest == null
                      ? 'No orders yet'
                      : 'Last order: ${DateFormat('MMM d').format(latest.orderDate)}');

              final paymentStatus = latest?.paymentStatus;
              final customerReport = reports.customerRevenue[customer.name];
              final ltv = customerReport?.revenue ?? 0;

              return _CustomerListCard(
                customer: customer,
                phone: customer.phone,
                isActive: customer.isActive,
                paymentStatus: paymentStatus,
                scheduleLabel: scheduleLabel,
                ltv: ltv,
                onTap: () => context.push('/owner/customers/${customer.id}'),
              );
            },
          ),
        ),
      );
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 8)));
    }
    return slivers;
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(icon, size: 80, color: AppColors.textLight),
            ),
            const SizedBox(height: 32),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: FilledButton.icon(
                  onPressed: onAction,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
            if (showArrow) ...[
              const SizedBox(height: 48),
              AnimatedBuilder(
                animation: _arrowController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, 10 * _arrowController.value),
                    child: const Icon(
                      Icons.keyboard_double_arrow_down_rounded,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;
  const _GroupHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '${title.toUpperCase()} • $count CUSTOMERS',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.textLight,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ],
    );
  }
}

class _CustomerListCard extends StatelessWidget {
  final Customer customer;
  final String phone;
  final bool isActive;
  final PaymentStatus? paymentStatus;
  final String scheduleLabel;
  final double ltv;
  final VoidCallback onTap;

  const _CustomerListCard({
    required this.customer,
    required this.phone,
    required this.isActive,
    required this.paymentStatus,
    required this.scheduleLabel,
    required this.ltv,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final payment = _PaymentPill.from(paymentStatus);
    final activePill = isActive
        ? const _Pill(label: 'ACTIVE', fg: AppColors.success, bg: AppColors.successLighter)
        : const _Pill(label: 'INACTIVE', fg: AppColors.textSecondary, bg: AppColors.backgroundSecondary);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            phone.trim().isEmpty ? '—' : phone.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        activePill,
                        const SizedBox(height: 8),
                        payment.pill,
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        scheduleLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (ltv > 0) ...[
                      const SizedBox(width: 10),
                      _Pill(
                        label: '₹${NumberFormat.compact().format(ltv)}',
                        fg: AppColors.primary,
                        bg: AppColors.primaryLighter,
                        isUppercase: false,
                      ),
                    ],
                  ],
                ),
              ],
            ),
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
        _Pill(label: 'PAID', fg: AppColors.success, bg: AppColors.successLighter),
      ),
      PaymentStatus.partial => const _PaymentPill._(
        _Pill(label: 'PARTIAL', fg: AppColors.warning, bg: AppColors.warningLighter),
      ),
      PaymentStatus.unpaid => const _PaymentPill._(
        _Pill(label: 'UNPAID', fg: AppColors.error, bg: AppColors.errorLighter),
      ),
      _ => const _PaymentPill._(
        _Pill(label: '—', fg: AppColors.textSecondary, bg: AppColors.backgroundSecondary, isUppercase: false),
      ),
    };
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color fg;
  final Color bg;
  final bool isUppercase;

  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.isUppercase = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withValues(alpha: 0.18)),
      ),
      child: Text(
        isUppercase ? label.toUpperCase() : label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: fg,
          letterSpacing: isUppercase ? 0.8 : -0.2,
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
  final ValueChanged<String?> onSelect;

  const _RouteChipsRow({
    required this.selectedRouteId,
    required this.availableRouteIds,
    required this.routesById,
    required this.routesLoaded,
    required this.routes,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final chips = <_RouteChipData>[
      const _RouteChipData(id: null, label: 'All Routes'),
      if (!routesLoaded && routes.isEmpty)
        const _RouteChipData(id: 'loading', label: 'Loading…')
      else
        ...availableRouteIds.map((id) {
          final name = routesById[id]?.name ?? 'Unknown';
          return _RouteChipData(id: id, label: name);
        }),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final c in chips) ...[
            _RouteChip(
              label: c.label,
              isSelected: c.id != 'loading' && selectedRouteId == c.id,
              isDisabled: c.id == 'loading',
              onTap: () {
                if (c.id == 'loading') return;
                onSelect(c.id);
              },
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _RouteChipData {
  final String? id;
  final String label;
  const _RouteChipData({required this.id, required this.label});
}

class _RouteChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDisabled;
  final VoidCallback onTap;

  const _RouteChip({
    required this.label,
    required this.isSelected,
    required this.isDisabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isSelected
        ? AppColors.primary
        : AppColors.backgroundSecondary.withValues(alpha: 0.7);
    final fg = isSelected
        ? Colors.white
        : isDisabled
        ? AppColors.textDisabled
        : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: isDisabled ? null : onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
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
  final String initialQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchSheet({
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
            TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Name, phone, or address…',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: initialQuery.isNotEmpty
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
                  ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                  : const Icon(Icons.chevron_right_rounded, color: AppColors.textLight),
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
                          fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
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
