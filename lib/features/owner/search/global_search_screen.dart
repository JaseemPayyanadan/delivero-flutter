import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../data/models/customer.dart';
import '../../../core/utils/route_refs.dart';
import '../../../data/models/order.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final TextEditingController _query = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool _matchesCustomer(Customer c, String lower) {
    if (lower.isEmpty) return false;
    return c.name.toLowerCase().contains(lower) ||
        c.phone.contains(_q.trim()) ||
        c.address.toLowerCase().contains(lower) ||
        (c.ownerName?.toLowerCase().contains(lower) ?? false);
  }

  bool _matchesOrder(Order o, String lower) {
    if (lower.isEmpty) return false;
    return o.customerName.toLowerCase().contains(lower) ||
        o.id.toLowerCase().contains(lower) ||
        o.customerPhone.contains(_q.trim()) ||
        o.customerAddress.toLowerCase().contains(lower) ||
        o.customerEmail.toLowerCase().contains(lower);
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    final orders = ref.watch(ordersProvider);
    final routes = ref.watch(routesProvider);
    final lower = _q.trim().toLowerCase();

    final matchedCustomers = lower.isEmpty
        ? <Customer>[]
        : customers.where((c) => _matchesCustomer(c, lower)).take(12).toList();

    final matchedOrders = lower.isEmpty
        ? <Order>[]
        : orders.where((o) => _matchesOrder(o, lower)).take(12).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        titleWidget: TextField(
          controller: _query,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search customers & orders…',
            border: InputBorder.none,
            isDense: true,
          ),
          onChanged: (v) => setState(() => _q = v),
        ),
        actions: [
          if (_q.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () {
                _query.clear();
                setState(() => _q = '');
              },
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
      body: lower.isEmpty
          ? const DeliveroEmptyState(
              title: 'Start searching',
              subtitle:
                  'Type a name, phone, order id, or address to find matching results',
              icon: Icons.search_rounded,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                if (matchedOrders.isNotEmpty) ...[
                  _SectionTitle('Orders (${matchedOrders.length})'),
                  ...matchedOrders.map((o) {
                    return _OrderHitTile(
                      order: o,
                      routeLabel: RouteRefs.routeLabelForRef(
                        o.assignedRoute,
                        routes,
                      ),
                      onTap: () => context.push('/owner/orders/${o.id}'),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                if (matchedCustomers.isNotEmpty) ...[
                  _SectionTitle('Customers (${matchedCustomers.length})'),
                  ...matchedCustomers.map(
                    (c) => _CustomerHitTile(
                      customer: c,
                      onTap: () => context.push('/owner/customers/${c.id}'),
                    ),
                  ),
                ],
                if (matchedOrders.isEmpty && matchedCustomers.isEmpty)
                  const DeliveroEmptyState(
                    title: 'No matches found',
                    subtitle:
                        'Try searching for something else or check for typos',
                    icon: Icons.search_off_rounded,
                  ),
              ],
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: context.appTextStyles.caption.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _OrderHitTile extends StatelessWidget {
  final Order order;
  final String routeLabel;
  final VoidCallback onTap;

  const _OrderHitTile({
    required this.order,
    required this.routeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          order.customerName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${order.id} · $routeLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _CustomerHitTile extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerHitTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          customer.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(customer.phone, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
