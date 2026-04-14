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

    final availableRouteIds = customers
        .map((c) {
          final route = routes.firstWhereOrNull(
            (r) => r.id == c.assignedRoute || r.name == c.assignedRoute,
          );
          return route?.id;
        })
        .whereType<String>()
        .toSet()
        .toList();

    final filteredCustomers = customers.where((customer) {
      final matchesSearch =
          customer.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (customer.ownerName?.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ??
              false) ||
          customer.phone.contains(_searchQuery) ||
          customer.address.toLowerCase().contains(_searchQuery.toLowerCase());

      final route = routes.firstWhereOrNull(
        (r) =>
            r.id == customer.assignedRoute || r.name == customer.assignedRoute,
      );
      final matchesRoute =
          _selectedRouteId == null ||
          customer.assignedRoute == _selectedRouteId ||
          route?.id == _selectedRouteId;

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
      body: RefreshIndicator(
        onRefresh: () => ref.read(customersProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            if (!noCustomersYet) ...[
              DeliveroSliverHeader(
                title: 'Customers',
                subtitle: '${customers.length} customers',
                expandedHeight: 140,
                floating: true,
                pinned: true,
                actions: [
                  PrimarySquareIconButton(
                    icon: Icons.add_rounded,
                    onPressed: () => context.push('/owner/customers/add'),
                  ),
                  const SizedBox(width: 16),
                ],
              ),
              SliverToBoxAdapter(
                child: _buildSearchAndFilter(
                  routes,
                  availableRouteIds,
                  partners: filteredCustomers.length,
                  orders: totalOrdersCount,
                  routesLoaded: routesLoaded,
                ),
              ),
            ],
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
                  actionLabel: customers.isEmpty
                      ? 'Add Customer'
                      : 'Clear Search',
                  onAction: customers.isEmpty
                      ? () => context.push('/owner/customers/add')
                      : () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final customer = filteredCustomers[index];
                    final route = routes.firstWhereOrNull(
                      (r) =>
                          r.id == customer.assignedRoute ||
                          r.name == customer.assignedRoute,
                    );
                    final routeName = !routesLoaded && routes.isEmpty
                        ? 'Loading route…'
                        : (route?.name ??
                              (customer.assignedRoute ?? 'No Route'));

                    final customerOrders =
                        ordersByCustomer[customer.id] ?? const [];

                    DateTime? lastOrderDate;

                    for (var o in customerOrders) {
                      if (lastOrderDate == null ||
                          o.orderDate.isAfter(lastOrderDate)) {
                        lastOrderDate = o.orderDate;
                      }
                    }

                    final customerReport =
                        reports.customerRevenue[customer.name];
                    final ltv = customerReport?.revenue ?? 0;
                    final totalOrders = customerOrders.length;

                    return _buildCustomerCard(
                      customer,
                      routeName,
                      lastOrderDate,
                      ltv,
                      totalOrders,
                    );
                  }, childCount: filteredCustomers.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(
    List<DeliveryRoute> routes,
    List<String> availableRouteIds, {
    required int partners,
    required int orders,
    required bool routesLoaded,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
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
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone, or address…',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildSummaryStrip(partners, orders),
                const SizedBox(height: 16),
                const Text(
                  'Routes',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textLight,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildRouteTab(null, 'All'),
                      if (!routesLoaded && routes.isEmpty)
                        _buildRouteTab('loading', 'Loading…')
                      else
                        ...availableRouteIds
                            .sortedBy(
                              (id) =>
                                  routes
                                      .firstWhereOrNull((r) => r.id == id)
                                      ?.name ??
                                  '',
                            )
                            .map((routeId) {
                              final route = routes.firstWhereOrNull(
                                (r) => r.id == routeId,
                              );
                              return _buildRouteTab(
                                routeId,
                                route?.name ?? 'Unknown Route',
                              );
                            }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteTab(String? routeId, String label) {
    final isLoading = routeId == 'loading';
    final isSelected = !isLoading && _selectedRouteId == routeId;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: isLoading
            ? null
            : () {
                setState(() {
                  _selectedRouteId = isSelected ? null : routeId;
                });
              },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : isLoading
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

  Widget _buildSummaryStrip(int partners, int orders) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryMetric(
              label: 'Customers',
              value: partners.toString(),
              color: AppColors.textPrimary,
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: AppColors.divider,
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          Expanded(
            child: _buildSummaryMetric(
              label: 'Orders',
              value: orders.toString(),
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: AppColors.textLight,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(
    Customer customer,
    String routeName,
    DateTime? lastOrderDate,
    double ltv,
    int totalOrders,
  ) {
    final initials = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().split(RegExp(r'\s+')).take(2).map((p) {
            return p.isEmpty ? '' : p[0].toUpperCase();
          }).join();

    final ltvText = '₹${NumberFormat.compact().format(ltv)}';
    final lastOrderText = lastOrderDate != null
        ? DateFormat('MMM d').format(lastOrderDate)
        : 'No orders yet';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/owner/customers/${customer.id}'),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
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
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLighter.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
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
                                fontSize: 17,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Text(
                                      routeName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textLight,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.trending_up_rounded,
                          label: 'LTV',
                          value: ltvText,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _InfoChip(
                          icon: Icons.shopping_bag_outlined,
                          label: 'Orders',
                          value: totalOrders.toString(),
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Last order',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          lastOrderText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textLight,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
