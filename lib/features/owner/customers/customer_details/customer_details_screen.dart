import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/providers.dart';
import '../../../../core/orders/order_sort.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/maps_launch.dart';
import '../../../../core/utils/route_refs.dart';
import '../../../../core/widgets/delivero_gradient_header.dart';
import '../../../../core/widgets/delivero_sliver_header.dart';
import '../../../../data/models/customer.dart';
import '../../../../data/models/food_item.dart';
import '../../../../data/models/order.dart';
import '../../../../data/models/product_unit.dart';
import 'widgets/customer_collect_payment_sheet.dart';
import 'widgets/customer_contact_card.dart';
import 'widgets/customer_financial_card.dart';
import 'widgets/customer_identity_card.dart';
import 'widgets/customer_order_history_card.dart';
import 'widgets/customer_recurring_card.dart';
import '../../../../core/widgets/detail_overflow_menu.dart';

class CustomerDetailsScreen extends ConsumerWidget {
  final String customerId;
  const CustomerDetailsScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);
    final customersLoaded = ref.watch(customersLoadedProvider);
    final routes = ref.watch(routesProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    final orders = ref.watch(ordersProvider);
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final foodItems = ref.watch(foodItemsProvider);
    final foodItemsLoaded = ref.watch(foodItemsLoadedProvider);

    final customer = customers.firstWhereOrNull((c) => c.id == customerId);

    final isLoading =
        !(customersLoaded && routesLoaded && ordersLoaded && foodItemsLoaded) &&
        customers.isEmpty &&
        routes.isEmpty &&
        orders.isEmpty &&
        foodItems.isEmpty;

    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: const DeliveroAppBar(title: 'Customer'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (customer == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        appBar: const DeliveroAppBar(title: 'Customer'),
        body: const Center(child: Text('Customer not found')),
      );
    }

    final customerOrders = orders
        .where((o) => o.customerId == customer.id)
        .toList();
    sortOrdersByDate(customerOrders);

    final pendingRevenue = customerOrders
        .where((o) => o.paymentStatus != PaymentStatus.paid)
        .fold(0.0, (sum, o) => sum + (o.totalAmount - (o.amountPaid ?? 0)));
    final ltv = customerOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final lastOrderDate = customerOrders.isNotEmpty
        ? customerOrders.first.orderDate
        : null;

    final Map<String, double> catalogPriceById = {
      for (final FoodItem item in foodItems) item.id: item.price,
    };
    final Map<String, ProductUnit> unitById = {
      for (final FoodItem item in foodItems) item.id: item.unit,
    };

    final recurringItems = (customer.products ?? const <CustomerProduct>[])
        .where((p) => p.quantity > 0)
        .toList();

    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    final phone = customer.phone.trim();
    final email = customer.email.trim();
    final address = customer.address.trim();
    final ownerName = customer.ownerName?.trim() ?? '';
    final routeLabel = routesLoaded
        ? RouteRefs.routeLabelForRef(customer.assignedRoute, routes)
        : '';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            context.push('/owner/orders/create', extra: customerId),
        backgroundColor: AppColors.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text(
          'New order',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DeliveroGradientHeader(
                title: 'Customer',
                subtitle: customer.name,
                onBack: Navigator.of(context).canPop()
                    ? () => context.pop()
                    : null,
                horizontalPadding: 20,
                bannerHeight: 104,
                overlap: 36,
                actions: [_buildOverflowMenu(context, ref, customer)],
                overlapChild: CustomerIdentityCard(
                  name: customer.name,
                  initials: _initials(customer.name),
                  routeLabel: routeLabel,
                  isActive: customer.isActive,
                  phone: phone,
                  ownerName: ownerName,
                  address: address,
                  onCall: phone.isEmpty ? null : () => _launchPhone(phone),
                  onOpenAddress: address.isEmpty
                      ? null
                      : () => _launchMaps(address),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CustomerFinancialCard(
                      totalOrders: customerOrders.length,
                      lifetimeValue: ltv,
                      outstanding: pendingRevenue,
                      lastOrderDate: lastOrderDate,
                      money: money,
                      onCollect: unsettledOrders(customerOrders).isEmpty
                          ? null
                          : () => showCustomerCollectPaymentSheet(
                              context: context,
                              ref: ref,
                              customerOrders: customerOrders,
                            ),
                    ),
                    const SizedBox(height: 22),
                    CustomerRecurringCard(
                      items: recurringItems,
                      unitById: unitById,
                      scheduleLabel: _inferScheduleLabel(customerOrders),
                      estimatedPerDelivery: _estimatePerDelivery(
                        recurringItems,
                        catalogPriceById,
                      ),
                    ),
                    const SizedBox(height: 22),
                    CustomerOrderHistoryCard(orders: customerOrders),
                    const SizedBox(height: 22),
                    CustomerContactCard(
                      phone: phone,
                      email: email,
                      routeLabel: routeLabel,
                      discountPercentage: customer.discountPercentage ?? 0,
                      customerSince: DateFormat(
                        'd MMM yyyy',
                      ).format(customer.createdAt),
                      onCall: phone.isEmpty ? null : () => _launchPhone(phone),
                      onEmail: email.isEmpty ? null : () => _launchEmail(email),
                    ),
                    SizedBox(height: 90 + MediaQuery.paddingOf(context).bottom),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverflowMenu(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) {
    return DetailOverflowMenu(
      actions: [
        DetailMenuAction(
          label: 'Edit customer',
          icon: Icons.edit_rounded,
          onSelected: () =>
              context.push('/owner/customers/edit/${customer.id}'),
        ),
        DetailMenuAction(
          label: 'Delete customer',
          icon: Icons.delete_outline_rounded,
          destructive: true,
          onSelected: () => _confirmAndDeleteCustomer(
            context,
            ref,
            customer.id,
            customer.name,
          ),
        ),
      ],
    );
  }

}

double? _estimatePerDelivery(
  List<CustomerProduct> items,
  Map<String, double> catalogPriceById,
) {
  if (items.isEmpty) return null;
  double total = 0;
  for (final p in items) {
    final unit = p.customPrice ?? catalogPriceById[p.id];
    if (unit == null) continue;
    total += unit * p.quantity;
  }
  return total <= 0 ? null : total;
}

String _inferScheduleLabel(List<Order> orders) {
  if (orders.isEmpty) return '—';
  final last = orders.take(10).toList();
  final counts = <int, int>{};
  for (final o in last) {
    counts[o.orderDate.weekday] = (counts[o.orderDate.weekday] ?? 0) + 1;
  }
  if (counts.isEmpty) return '—';
  final top = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return top.take(3).map((e) => _weekdayShort(e.key)).join(', ');
}

String _weekdayShort(int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return 'Mon';
    case DateTime.tuesday:
      return 'Tue';
    case DateTime.wednesday:
      return 'Wed';
    case DateTime.thursday:
      return 'Thu';
    case DateTime.friday:
      return 'Fri';
    case DateTime.saturday:
      return 'Sat';
    case DateTime.sunday:
      return 'Sun';
  }
  return '—';
}

String _initials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
  final w = words[0];
  return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
}

Future<void> _launchPhone(String phone) async {
  final digits = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return;
  await launchUrl(
    Uri(scheme: 'tel', path: digits),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> _launchEmail(String email) async {
  final trimmed = email.trim();
  if (trimmed.isEmpty) return;
  await launchUrl(
    Uri(scheme: 'mailto', path: trimmed),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> _launchMaps(String address) async {
  await openMapsForAddress(address);
}

Future<void> _confirmAndDeleteCustomer(
  BuildContext context,
  WidgetRef ref,
  String customerId,
  String customerName,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete this customer?'),
      content: Text(
        'Remove "$customerName" from your list. Past orders are not deleted, but you cannot undo this.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(
            'Keep customer',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textLight,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            'Delete',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  try {
    await ref.read(customersProvider.notifier).deleteCustomer(customerId);
    if (context.mounted) {
      Navigator.pop(context); // close loader
      context.pop(); // back
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.pop(context); // close loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not delete customer. Try again.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }
}
