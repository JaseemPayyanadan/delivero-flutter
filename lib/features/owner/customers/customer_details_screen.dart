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

Future<void> _confirmAndDeleteCustomer(
  BuildContext context,
  WidgetRef ref,
  String customerId,
  String customerName,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text(
        'Delete this customer?',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
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

    final route = routes.firstWhereOrNull(
      (r) => r.id == customer.assignedRoute || r.name == customer.assignedRoute,
    );

    final customerOrders = orders
        .where((o) => o.customerId == customer.id)
        .toList();
    customerOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    final totalRevenue = customerOrders.fold(
      0.0,
      (sum, o) => sum + o.totalAmount,
    );
    final pendingRevenue = customerOrders
        .where((o) => o.paymentStatus != PaymentStatus.paid)
        .fold(0.0, (sum, o) => sum + (o.totalAmount - (o.amountPaid ?? 0)));
    final lastOrderDate = customerOrders.firstOrNull?.orderDate;

    final Map<String, double> catalogPriceById = {
      for (final FoodItem item in foodItems) item.id: item.price,
    };

    final displayRoute =
        route?.name ?? (customer.assignedRoute ?? 'Unassigned');
    final rawAddress = customer.address.trim();
    final displayAddress =
        rawAddress.isEmpty ? 'Address not available' : rawAddress;
    final phoneDigits = customer.phone.trim().replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );
    final ownerDisplay = customer.ownerName?.trim().isNotEmpty == true
        ? customer.ownerName!.trim()
        : 'Not added';

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          DeliveroSliverHeader(
            title: customer.name,
            subtitle: displayRoute,
            expandedHeight: 140,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                tooltip: 'Edit customer',
                onPressed: () =>
                    context.push('/owner/customers/edit/$customerId'),
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
              IconButton(
                tooltip: 'Delete customer',
                onPressed: () => _confirmAndDeleteCustomer(
                  context,
                  ref,
                  customer.id,
                  customer.name,
                ),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
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
                  _CustomerHeroCard(
                    customerName: customer.name,
                    routeLabel: displayRoute,
                    avatarText: customer.name.trim().isNotEmpty
                        ? customer.name.trim()[0].toUpperCase()
                        : '?',
                    ownerDisplay: ownerDisplay,
                    displayAddress: displayAddress,
                    phone: customer.phone,
                    onCall: phoneDigits.isEmpty
                        ? null
                        : () async {
                            final ok = await launchUrl(
                              Uri(scheme: 'tel', path: phoneDigits),
                            );
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Unable to start call',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.error,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                    onDirections: rawAddress.isEmpty
                        ? null
                        : () async {
                            final uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(rawAddress)}',
                            );
                            final ok = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Unable to open maps',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: AppColors.error,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                  const SizedBox(height: 14),
                  _KpiStrip(
                    items: [
                      _KpiItem(
                        label: 'Lifetime Value',
                        value:
                            '₹${NumberFormat.compact().format(totalRevenue)}',
                        icon: Icons.trending_up_rounded,
                        color: AppColors.success,
                      ),
                      _KpiItem(
                        label: 'Outstanding',
                        value:
                            '₹${NumberFormat.compact().format(pendingRevenue)}',
                        icon: Icons.account_balance_wallet_rounded,
                        color: pendingRevenue > 0
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      _KpiItem(
                        label: 'Orders',
                        value: customerOrders.length.toString(),
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.primary,
                      ),
                      _KpiItem(
                        label: 'Last Order',
                        value: lastOrderDate == null
                            ? '—'
                            : DateFormat('MMM d').format(lastOrderDate),
                        icon: Icons.calendar_today_rounded,
                        color: AppColors.info,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _SectionCard(
                    title: 'Products & pricing',
                    action: TextButton.icon(
                      onPressed: () =>
                          context.push('/owner/customers/edit/$customerId'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text(
                        'Edit',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    child: _buildConfigurationCard(
                      context,
                      customerId,
                      customer,
                      catalogPriceById,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _SectionCard(
                    title: 'Recent Orders',
                    child: _RecentOrdersList(
                      orders: customerOrders.take(6).toList(),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationCard(
    BuildContext context,
    String customerId,
    Customer customer,
    Map<String, double> catalogPriceById,
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
            onTap: () =>
                context.push('/owner/customers/edit/$customerId'),
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
                            '${p.quantity} units each order',
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
            '#${o.id.substring(0, 8).toUpperCase()} • $dateLabel',
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
          trailing: Text(
            '₹${NumberFormat.decimalPattern().format(o.totalAmount)}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }
}
