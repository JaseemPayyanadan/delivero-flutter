import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../app/reports_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
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

  String _formatIndex(int index) {
    final value = index + 1;
    return value < 10 ? '0$value' : value.toString();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch phone call')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final customersLoaded = ref.watch(customersLoadedProvider);
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

    double totalOutstanding = 0;
    int totalOrdersCount = 0;
    for (final customer in filteredCustomers) {
      final customerOrders = ordersByCustomer[customer.id] ?? const [];
      totalOrdersCount += customerOrders.length;
      for (final o in customerOrders) {
        if (o.paymentStatus != PaymentStatus.paid) {
          totalOutstanding += (o.totalAmount - (o.amountPaid ?? 0));
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          DeliveroSliverHeader(
            title: 'Customers',
            subtitle: '${customers.length} business partners',
            expandedHeight: 140,
            floating: true,
            pinned: true,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.backgroundSecondary,
                  child: const Text(
                    'CM',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: _buildSearchAndFilter(
              routes,
              availableRouteIds,
              partners: filteredCustomers.length,
              outstanding: totalOutstanding,
              orders: totalOrdersCount,
            ),
          ),
          if (!customersLoaded && customers.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filteredCustomers.isEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.6,
                child: _buildEmptyState(
                  title: customers.isEmpty
                      ? 'No Customers Managed'
                      : 'No Matching Results',
                  subtitle: customers.isEmpty
                      ? 'Add your first customer to start tracking orders and logistics.'
                      : 'Try adjusting your search criteria or route filters.',
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
                  final routeName =
                      route?.name ?? (customer.assignedRoute ?? 'No Route');

                  final customerOrders =
                      ordersByCustomer[customer.id] ?? const [];

                  double outstanding = 0;
                  DateTime? lastOrderDate;

                  for (var o in customerOrders) {
                    if (o.paymentStatus != PaymentStatus.paid) {
                      outstanding += (o.totalAmount - (o.amountPaid ?? 0));
                    }
                    if (lastOrderDate == null ||
                        o.orderDate.isAfter(lastOrderDate)) {
                      lastOrderDate = o.orderDate;
                    }
                  }

                  // Get LTV from reports if available
                  final customerReport = reports.customerRevenue[customer.name];
                  final ltv = customerReport?.revenue ?? 0;
                  final totalOrders = customerOrders.length;

                  return _buildCustomerCard(
                    _formatIndex(index),
                    customer,
                    routeName,
                    outstanding,
                    lastOrderDate,
                    ltv,
                    totalOrders,
                  );
                }, childCount: filteredCustomers.length),
              ),
            ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/owner/customers/add'),
          backgroundColor: AppColors.primary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: const Icon(Icons.add_business_rounded, color: Colors.white),
          label: const Text(
            'Add Customer',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter(
    List<DeliveryRoute> routes,
    List<String> availableRouteIds, {
    required int partners,
    required double outstanding,
    required int orders,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search partners, routes, IDs...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textLight,
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
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryStrip(partners, outstanding, orders),
          const SizedBox(height: 20),
          const Text(
            'LOGISTICS ROUTES',
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
                _buildRouteTab(null, 'All Partners'),
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
    );
  }

  Widget _buildRouteTab(String? routeId, String label) {
    final isSelected = _selectedRouteId == routeId;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: () => setState(() => _selectedRouteId = routeId),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppColors.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryStrip(int partners, double outstanding, int orders) {
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
              label: 'Partners',
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
              label: 'Outstanding',
              value: '₹${NumberFormat.compact().format(outstanding)}',
              color: AppColors.warning,
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
    String indexLabel,
    Customer customer,
    String routeName,
    double outstanding,
    DateTime? lastOrderDate,
    double ltv,
    int totalOrders,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: () => context.push('/owner/customers/${customer.id}'),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
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
                              fontSize: 18,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppColors.textLight,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  routeName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _buildMetric(
                                'LTV',
                                '₹${NumberFormat.compact().format(ltv)}',
                                Icons.trending_up_rounded,
                              ),
                              const SizedBox(width: 14),
                              _buildMetric(
                                'ORDERS',
                                totalOrders.toString(),
                                Icons.shopping_bag_outlined,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildQuickActions(customer),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  border: const Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LAST ENGAGEMENT',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textLight,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          lastOrderDate != null
                              ? DateFormat('MMM d').format(lastOrderDate)
                              : 'FIRST CONTACT',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    _buildOutstandingBadge(outstanding),
                  ],
                ),
              ),
              Container(
                height: 3,
                width: double.infinity,
                color: outstanding > 0 ? AppColors.warning : AppColors.success,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutstandingBadge(double outstanding) {
    final hasDue = outstanding > 0.01;
    if (!hasDue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.18)),
        ),
        child: const Text(
          'Cleared',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: AppColors.success,
            letterSpacing: 0.4,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Text(
        '₹${NumberFormat.compact().format(outstanding)} due',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: AppColors.warning,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: AppColors.textLight),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textLight,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(Customer customer) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.call_rounded,
          color: AppColors.success,
          onTap: () => _makePhoneCall(customer.phone),
        ),
      ],
    );
  }

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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}
