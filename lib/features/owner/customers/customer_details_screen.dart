import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/food_item.dart';
import '../../../data/models/order.dart';

class CustomerDetailsScreen extends ConsumerWidget {
  final String customerId;
  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final routes = ref.watch(routesProvider);
    final orders = ref.watch(ordersProvider);
    final foodItems = ref.watch(foodItemsProvider);

    final customer = customers.firstWhereOrNull((c) => c.id == customerId);

    if (customer == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: const DeliveroAppBar(title: 'Customer'),
        body: const Center(child: Text('Enterprise Partner Not Found')),
      );
    }

    final route = routes.firstWhereOrNull(
      (r) => r.id == customer.assignedRoute || r.name == customer.assignedRoute,
    );

    final customerOrders = orders
        .where((o) => o.customerId == customer.id)
        .toList();
    final totalRevenue = customerOrders.fold(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );
    final pendingRevenue = customerOrders
        .where((o) => o.paymentStatus != PaymentStatus.paid)
        .fold(0.0, (sum, o) => sum + (o.totalAmount - (o.amountPaid ?? 0)));

    final Map<String, double> catalogPriceById = {
      for (final FoodItem item in foodItems) item.id: item.price,
    };

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          DeliveroSliverHeader(
            title: customer.name,
            subtitle: route?.name ?? 'Unassigned route',
            expandedHeight: 140,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                onPressed: () => context.push('/owner/customers/edit/$customerId'),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLighter.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              customer.name.trim().isNotEmpty
                                  ? customer.name.trim()[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
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
                                  fontSize: 18,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Text(
                                  (route?.name ?? 'UNASSIGNED ROUTE')
                                      .toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildFinancialSummary(totalRevenue, pendingRevenue),
                  const SizedBox(height: 32),
                  _buildSectionTitle('ENTERPRISE CONTACTS'),
                  _buildContactCard(customer),
                  const SizedBox(height: 32),
                  _buildSectionTitle('LOGISTICS CONFIGURATION'),
                  _buildConfigurationCard(customer, catalogPriceById),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: AppColors.textLight,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildFinancialSummary(double ltv, double outstanding) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricBox(
            'LIFETIME VALUE',
            '₹${NumberFormat.compact().format(ltv)}',
            AppColors.success,
            Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricBox(
            'OUTSTANDING',
            '₹${NumberFormat.compact().format(outstanding)}',
            outstanding > 0 ? AppColors.error : AppColors.success,
            Icons.account_balance_wallet_rounded,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricBox(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color.withValues(alpha: 0.7)),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.textLight,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Customer customer) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildContactTile(
            Icons.person_pin_rounded,
            'Decision Maker',
            customer.ownerName ?? 'Proprietor',
          ),
          _buildContactTile(
            Icons.phone_iphone_rounded,
            'Primary Contact',
            customer.phone,
            onTap: () => launchUrl(Uri.parse('tel:${customer.phone}')),
            trailing: const Icon(
              Icons.call_rounded,
              size: 16,
              color: AppColors.success,
            ),
          ),
          _buildContactTile(
            Icons.map_rounded,
            'Operational HQ',
            customer.address,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(
    IconData icon,
    String label,
    String value, {
    VoidCallback? onTap,
    Widget? trailing,
    bool isLast = false,
  }) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          title: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
            ),
          ),
          subtitle: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: onTap != null ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
          trailing: trailing,
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: AppColors.divider),
          ),
      ],
    );
  }

  Widget _buildConfigurationCard(
    Customer customer,
    Map<String, double> catalogPriceById,
  ) {
    final products = customer.products ?? [];
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'NO CUSTOM CONTRACTS DEFINED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.textLight,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }

    return Column(
      children: products.map((p) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLighter,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2_rounded,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Default Commitment: ${p.quantity} Units',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              Builder(
                builder: (context) {
                  final catalogPrice = catalogPriceById[p.id];
                  final shownPrice = p.customPrice ?? catalogPrice;
                  final isContract = p.customPrice != null;
                  final label = isContract ? 'CONTRACT PRICE' : 'CATALOG PRICE';
                  final color = isContract
                      ? AppColors.success
                      : AppColors.textSecondary;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textLight,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        shownPrice == null
                            ? '-'
                            : '₹${NumberFormat.decimalPattern().format(shownPrice)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: color,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
