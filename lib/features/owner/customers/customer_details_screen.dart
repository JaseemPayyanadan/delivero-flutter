// ignore_for_file: unused_element, unused_element_parameter

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/providers.dart';
import '../../../core/orders/order_sort.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/maps_launch.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/utils/route_refs.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/food_item.dart';
import '../../../data/models/order.dart';
import '../../../data/models/product_unit.dart';
import '../orders/order_details/order_detail_formatting.dart';

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
  final days = top.take(3).map((e) => _weekdayShort(e.key)).toList();
  return days.join(', ');
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

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
  final w = words[0];
  return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
}

Future<void> _launchPhone(BuildContext context, String phone) async {
  final digits = phone.trim().replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return;
  await launchUrl(
    Uri(scheme: 'tel', path: digits),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> _launchEmail(BuildContext context, String email) async {
  final trimmed = email.trim();
  if (trimmed.isEmpty) return;
  await launchUrl(
    Uri(scheme: 'mailto', path: trimmed),
    mode: LaunchMode.externalApplication,
  );
}

Future<void> _launchMaps(BuildContext context, String address) async {
  await openMapsForAddress(address);
}

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

    final Map<String, double> catalogPriceById = {
      for (final FoodItem item in foodItems) item.id: item.price,
    };
    final Map<String, ProductUnit> unitById = {
      for (final FoodItem item in foodItems) item.id: item.unit,
    };

    final displayRoute = RouteRefs.routeLabelForRef(
      customer.assignedRoute,
      routes,
    );
    final rawAddress = customer.address.trim();

    final recurringItems = (customer.products ?? const <CustomerProduct>[])
        .where((p) => p.quantity > 0)
        .toList();
    final estimatedPerDelivery = _estimatePerDelivery(
      recurringItems,
      catalogPriceById,
    );
    final scheduleLabel = _inferScheduleLabel(customerOrders);

    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final ltv = customerOrders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final lastOrderDate = customerOrders.isNotEmpty
        ? customerOrders.first.orderDate
        : null;
    final phone = customer.phone.trim();
    final email = customer.email.trim();
    final ownerName = customer.ownerName?.trim() ?? '';
    final resolvedRoute = routesLoaded ? displayRoute : '';
    final heroSubtext = resolvedRoute.isNotEmpty ? resolvedRoute : '';
    final hasContactActions =
        phone.isNotEmpty || email.isNotEmpty || rawAddress.isNotEmpty;

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
      appBar: DeliveroAppBar(
        title: 'Customer Profile',
        centerTitle: true,
        backgroundColor: AppColors.backgroundSecondary,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit customer',
            onPressed: () => context.push('/owner/customers/edit/$customerId'),
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (value) {
              if (value == 'delete') {
                _confirmAndDeleteCustomer(
                  context,
                  ref,
                  customer.id,
                  customer.name,
                );
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete customer')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            // ── Hero ─────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              color: AppColors.backgroundSecondary,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 18,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _initials(customer.name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 26,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    customer.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  if (heroSubtext.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      heroSubtext,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _StatusPill(active: customer.isActive),
                  if (hasContactActions) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (phone.isNotEmpty) ...[
                          _QuickActionButton(
                            icon: Icons.call_rounded,
                            label: 'Call',
                            color: AppColors.success,
                            onTap: () => _launchPhone(context, phone),
                          ),
                        ],
                        if (email.isNotEmpty) ...[
                          if (phone.isNotEmpty) const SizedBox(width: 24),
                          _QuickActionButton(
                            icon: Icons.email_rounded,
                            label: 'Email',
                            color: AppColors.info,
                            onTap: () => _launchEmail(context, email),
                          ),
                        ],
                        if (rawAddress.isNotEmpty) ...[
                          if (phone.isNotEmpty || email.isNotEmpty)
                            const SizedBox(width: 24),
                          _QuickActionButton(
                            icon: Icons.near_me_rounded,
                            label: 'Navigate',
                            color: AppColors.primary,
                            onTap: () => _launchMaps(context, rawAddress),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Contact & Info ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProfileCard(
                icon: Icons.contact_page_rounded,
                iconBg: AppColors.primaryLighter.withValues(alpha: 0.75),
                title: 'Contact & Info',
                child: Column(
                  children: [
                    if (phone.isNotEmpty)
                      _InfoRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: phone,
                        onTap: () => _launchPhone(context, phone),
                      ),
                    if (email.isNotEmpty)
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email,
                        onTap: () => _launchEmail(context, email),
                      ),
                    if (rawAddress.isNotEmpty)
                      _InfoRow(
                        icon: Icons.location_on_rounded,
                        label: 'Address',
                        value: rawAddress,
                        onTap: () => _launchMaps(context, rawAddress),
                      ),
                    if (ownerName.isNotEmpty)
                      _InfoRow(
                        icon: Icons.person_rounded,
                        label: 'Owner / Manager',
                        value: ownerName,
                      ),
                    if (resolvedRoute.isNotEmpty)
                      _InfoRow(
                        icon: Icons.alt_route_rounded,
                        label: 'Route',
                        value: resolvedRoute,
                      ),
                    if ((customer.discountPercentage ?? 0) > 0)
                      _InfoRow(
                        icon: Icons.discount_rounded,
                        label: 'Discount',
                        value:
                            '${(customer.discountPercentage ?? 0).toStringAsFixed(0)}% off all orders',
                      ),
                    _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Customer since',
                      value: DateFormat(
                        'd MMM yyyy',
                      ).format(customer.createdAt),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Financial Overview ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProfileCard(
                icon: Icons.account_balance_wallet_rounded,
                iconBg: AppColors.successLighter.withValues(alpha: 0.75),
                title: 'Financial Overview',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _FinancialTile(
                            label: 'Total Orders',
                            child: Text(
                              '${customerOrders.length}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FinancialTile(
                            label: 'Lifetime Value',
                            child: Text(
                              money.format(ltv),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: AppColors.primary,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _FinancialTile(
                            label: 'Outstanding',
                            child: Text(
                              money.format(pendingRevenue),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: pendingRevenue > 0.004
                                    ? AppColors.error
                                    : AppColors.success,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FinancialTile(
                            label: 'Last Order',
                            child: Text(
                              lastOrderDate == null
                                  ? '—'
                                  : DateFormat(
                                      'd MMM yy',
                                    ).format(lastOrderDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Recurring Order ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProfileCard(
                icon: Icons.autorenew_rounded,
                iconBg: AppColors.warningLighter.withValues(alpha: 0.75),
                title: 'Recurring Order',
                child: recurringItems.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'No recurring items set yet.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (final item in recurringItems.take(3)) ...[
                            _RecurringItemRow(
                              name: item.name,
                              quantity: item.quantity,
                              unit: unitById[item.id] ?? ProductUnit.quantity,
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (recurringItems.length > 3) ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '+${recurringItems.length - 3} more items',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textLight,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: _MetaPair(
                                  label: 'Frequency',
                                  value: scheduleLabel == '—'
                                      ? 'Weekly'
                                      : 'Weekly ($scheduleLabel)',
                                ),
                              ),
                              Expanded(
                                child: _MetaPair(
                                  label: 'Estimated total',
                                  value: estimatedPerDelivery == null
                                      ? '—'
                                      : '₹${NumberFormat.compact().format(estimatedPerDelivery)} /deliv.',
                                  alignEnd: true,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Order History ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ProfileCard(
                icon: Icons.history_rounded,
                iconBg: AppColors.infoLighter.withValues(alpha: 0.75),
                title: 'Order history',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (customerOrders.length > 10)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/owner/orders'),
                            child: Text(
                              'View all (${customerOrders.length})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    _RecentOrdersList(orders: customerOrders.take(10).toList()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Legacy UI sections remain below for future reuse.
  Widget _buildConfigurationCard(
    BuildContext context,
    String customerId,
    Customer customer,
    Map<String, double> catalogPriceById,
    Map<String, ProductUnit> unitById,
  ) {
    final products = customer.products ?? [];
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLighter.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No products linked yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Choose what this customer orders and optional custom prices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.95),
                fontWeight: FontWeight.w500,
                fontSize: 14,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () =>
                    context.push('/owner/customers/edit/$customerId'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.edit_calendar_outlined, size: 20),
                label: const Text(
                  'Set up products',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => context.push('/owner/food-items'),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'Open product catalog',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      itemCount: products.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = products[index];
        final catalogPrice = catalogPriceById[p.id];
        final shownPrice = p.customPrice ?? catalogPrice;
        final hasCustom = p.customPrice != null;
        final nf = NumberFormat.decimalPattern();

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push('/owner/customers/edit/$customerId'),
            child: Ink(
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLighter.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.inventory_2_rounded,
                        size: 22,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: AppColors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${p.quantity} ${(unitById[p.id] ?? ProductUnit.quantity).productionWord} each order',
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (hasCustom &&
                              catalogPrice != null &&
                              p.customPrice != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'List ${nf.format(catalogPrice)} → Your ${nf.format(p.customPrice!)}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: hasCustom
                                ? AppColors.successLighter.withValues(
                                    alpha: 0.85,
                                  )
                                : AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasCustom
                                  ? AppColors.success.withValues(alpha: 0.25)
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            hasCustom ? 'Custom' : 'List',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: hasCustom
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          shownPrice == null
                              ? '—'
                              : '₹${nf.format(shownPrice)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            color: hasCustom
                                ? AppColors.success
                                : AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to edit',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MergedContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final int valueMaxLines;

  const _MergedContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
    this.valueMaxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
        maxLines: valueMaxLines,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: onTap != null ? AppColors.primary : AppColors.textPrimary,
          height: 1.35,
        ),
      ),
      trailing: trailing,
    );
  }
}

class _CustomerHeroCard extends StatelessWidget {
  final String customerName;
  final String routeLabel;
  final String avatarText;
  final String ownerDisplay;
  final String displayAddress;
  final String phone;
  final VoidCallback? onCall;
  final VoidCallback? onDirections;

  const _CustomerHeroCard({
    required this.customerName,
    required this.routeLabel,
    required this.avatarText,
    required this.ownerDisplay,
    required this.displayAddress,
    required this.phone,
    required this.onCall,
    required this.onDirections,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    avatarText,
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
                      customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        routeLabel.toUpperCase(),
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
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 4),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          _MergedContactRow(
            icon: Icons.person_pin_rounded,
            label: 'Owner or manager',
            value: ownerDisplay,
          ),
          const Divider(height: 1, color: AppColors.divider),
          _MergedContactRow(
            icon: Icons.phone_iphone_rounded,
            label: 'Phone',
            value: phone.trim().isEmpty ? 'Not available' : phone.trim(),
            onTap: onCall,
            trailing: onCall != null
                ? const Icon(
                    Icons.call_rounded,
                    size: 18,
                    color: AppColors.success,
                  )
                : null,
          ),
          const Divider(height: 1, color: AppColors.divider),
          _MergedContactRow(
            icon: Icons.map_rounded,
            label: 'Address',
            value: displayAddress,
            onTap: onDirections,
            valueMaxLines: 4,
            trailing: onDirections != null
                ? const Icon(
                    Icons.near_me_outlined,
                    size: 18,
                    color: AppColors.info,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool active;
  const _StatusPill({required this.active});

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? AppColors.successLighter.withValues(alpha: 0.7)
        : AppColors.backgroundSecondary;
    final fg = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            active ? 'ACTIVE' : 'INACTIVE',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: fg,
              fontSize: 11,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final Widget child;
  const _ProfileCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.textPrimary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _RecurringItemRow extends StatelessWidget {
  final String name;
  final int quantity;
  final ProductUnit unit;
  const _RecurringItemRow({
    required this.name,
    required this.quantity,
    this.unit = ProductUnit.quantity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.restaurant_rounded,
            size: 18,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLighter.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              unit.compactAmount(quantity),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPair extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;
  const _MetaPair({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 1.0,
            color: AppColors.textLight,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 16,
              color: onTap != null ? AppColors.primary : AppColors.textLight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: onTap != null
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: AppColors.textLight,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FinancialTile extends StatelessWidget {
  final String label;
  final Widget child;
  const _FinancialTile({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 10,
              letterSpacing: 1.0,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PaymentPill extends StatelessWidget {
  final bool paid;
  const _PaymentPill({required this.paid});

  @override
  Widget build(BuildContext context) {
    final bg = paid
        ? AppColors.successLighter.withValues(alpha: 0.85)
        : AppColors.warningLighter.withValues(alpha: 0.85);
    final fg = paid ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        paid ? 'PAID' : 'PENDING',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PaymentMiniPill extends StatelessWidget {
  final PaymentStatus? status;
  const _PaymentMiniPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status ?? PaymentStatus.unpaid;
    final (bg, fg, label) = switch (s) {
      PaymentStatus.paid => (
        AppColors.successLighter.withValues(alpha: 0.85),
        AppColors.success,
        'PAID',
      ),
      PaymentStatus.partial => (
        AppColors.warningLighter.withValues(alpha: 0.85),
        AppColors.warning,
        'PART',
      ),
      PaymentStatus.unpaid => (
        AppColors.errorLighter.withValues(alpha: 0.85),
        AppColors.error,
        'DUE',
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 9,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _KpiItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _KpiStrip extends StatelessWidget {
  final List<_KpiItem> items;
  const _KpiStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = items[index];
          return Container(
            width: 178,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 16,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: item.color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _SectionCard({required this.title, required this.child, this.action});

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
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textLight,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                action ?? const SizedBox.shrink(),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          child,
        ],
      ),
    );
  }
}

class _RecentOrdersList extends StatelessWidget {
  final List<Order> orders;
  const _RecentOrdersList({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Text(
          'No orders yet',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
      itemCount: orders.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: AppColors.divider),
      itemBuilder: (context, index) {
        final o = orders[index];
        final statusColor = switch (o.status) {
          OrderStatus.pending => AppColors.warning,
          OrderStatus.delivered => AppColors.success,
          OrderStatus.cancelled => AppColors.error,
          _ => AppColors.info,
        };
        final dateLabel = DateFormat('MMM d').format(o.orderDate);
        return ListTile(
          onTap: () => context.push('/owner/orders/${o.id}'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          title: Text(
            '${orderDetailDisplayId(o.id)} · $dateLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          subtitle: Text(
            o.status.name.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${NumberFormat.decimalPattern().format(o.totalAmount)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              _PaymentMiniPill(status: o.paymentStatus),
            ],
          ),
        );
      },
    );
  }
}
