import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ignore_for_file: unused_element

import '../../../app/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/delivero_empty_state.dart';
import '../../../data/models/customer.dart';
import '../../../data/models/order.dart';
import '../../../data/models/delivery_route.dart';

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

  String _formatRupee(double amount) {
    final whole = amount == amount.roundToDouble();
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: whole ? 0 : 2,
    ).format(amount);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, Map<int, int>> _getPackagingSummary(List<Order> orders) {
    final Map<String, Map<int, int>> summary = {};
    for (final order in orders) {
      for (final item in order.items) {
        if (!summary.containsKey(item.foodItemName)) {
          summary[item.foodItemName] = {};
        }
        final qtyMap = summary[item.foodItemName]!;
        qtyMap[item.quantity] = (qtyMap[item.quantity] ?? 0) + 1;
      }
    }
    return summary;
  }

  Future<void> _printPackagingSummary(List<Order> filteredOrders) async {
    final summary = _getPackagingSummary(filteredOrders);
    if (summary.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'No items found for current filters.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final doc = pw.Document();

    final sortedEntries = summary.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Pack list',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.8,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'Generated: ${DateFormat('MMM d, yyyy • hh:mm a').format(now)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Orders in scope: ${filteredOrders.length}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
              columnWidths: {
                0: const pw.FlexColumnWidth(3.2),
                1: const pw.FlexColumnWidth(4.8),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Item',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Text(
                        'Pack sizes',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                ...sortedEntries.map((entry) {
                  final packSizes = entry.value.entries.toList()
                    ..sort((a, b) => a.key.compareTo(b.key));

                  final breakdown = packSizes
                      .map((e) => '${e.value} × ${e.key} unit packs')
                      .join('   |   ');

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          entry.key,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(10),
                        child: pw.Text(
                          breakdown,
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: 'packaging_manifest_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }

  void _showPackagingSummary(List<Order> filteredOrders) {
    final summary = _getPackagingSummary(filteredOrders);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text(
              'Packaging Manifest',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: summary.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No items found for current filters.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: summary.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final itemName = summary.keys.elementAt(index);
                    final packSizes = summary[itemName]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: packSizes.entries.map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLighter,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${e.value}x [${e.key} unit packs]',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CLOSE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textLight,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await _printPackagingSummary(filteredOrders);
            },
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text(
              'PRINT',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersProvider);
    final ordersLoaded = ref.watch(ordersLoadedProvider);
    final routes = ref.watch(routesProvider);
    final routesLoaded = ref.watch(routesLoadedProvider);
    final customers = ref.watch(customersProvider);
    final bool noOrdersYet = orders.isEmpty;

    String? routeIdForOrder(Order o) {
      final raw = o.assignedRoute?.trim();
      if (raw == null || raw.isEmpty) return null;
      final route = routes.firstWhereOrNull(
        (r) => r.id == raw || r.name == raw,
      );
      return route?.id ?? raw;
    }

    // Get unique route IDs from existing orders
    final availableRouteIds = orders
        .map(routeIdForOrder)
        .whereType<String>()
        .toSet()
        .toList();

    if (routesLoaded &&
        _selectedRouteId != null &&
        _selectedRouteId != '__unassigned__' &&
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
        '__unassigned__' => routeIdForOrder(order) == null,
        _ => routeIdForOrder(order) == _selectedRouteId,
      };

      final paymentStatus = order.paymentStatus ?? PaymentStatus.unpaid;
      final matchesPayment = _selectedPaymentStatus == null
          ? true
          : paymentStatus == _selectedPaymentStatus;

      return matchesSearch && matchesRoute && matchesPayment;
    }).toList();

    filteredOrders.sort((a, b) {
      // Priority sorting: Pending (1), Confirmed (2), Preparing (3), Ready (4), Cancelled (5), Delivered (6)
      final statusPriority = {
        OrderStatus.pending: 1,
        OrderStatus.confirmed: 2,
        OrderStatus.preparing: 3,
        OrderStatus.ready: 4,
        OrderStatus.cancelled: 5,
        OrderStatus.delivered: 6,
      };

      final aPriority = statusPriority[a.status] ?? 7;
      final bPriority = statusPriority[b.status] ?? 7;

      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }
      return b.orderDate.compareTo(a.orderDate);
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: DeliveroAppBar(
        title: 'Orders',
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
          IconButton(
            tooltip: 'Filter',
            onPressed: () => _showFiltersSheet(context),
            icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            if (!noOrdersYet)
              SliverToBoxAdapter(
                child: _buildFilters(
                  routes,
                  availableRouteIds,
                  routesLoaded: routesLoaded,
                ),
              ),
            if (!ordersLoaded && orders.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredOrders.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(hasAnyOrders: !noOrdersYet),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    _buildGroupedOrderWidgets(
                      filteredOrders,
                      routes,
                      customers,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedOrderWidgets(
    List<Order> filteredOrders,
    List<DeliveryRoute> routes,
    List<Customer> customers,
  ) {
    String routeLabelFor(Order order) {
      final raw = order.assignedRoute?.trim();
      String? customerRoute() {
        final byId = customers.firstWhereOrNull(
          (c) => c.id == order.customerId,
        );
        if (byId?.assignedRoute?.trim().isNotEmpty == true) {
          return byId!.assignedRoute!.trim();
        }

        final phone = order.customerPhone.trim();
        if (phone.isNotEmpty) {
          final byPhone = customers.firstWhereOrNull(
            (c) => c.phone.trim() == phone,
          );
          if (byPhone?.assignedRoute?.trim().isNotEmpty == true) {
            return byPhone!.assignedRoute!.trim();
          }
        }

        final name = order.customerName.trim().toLowerCase();
        if (name.isNotEmpty) {
          final byName = customers.firstWhereOrNull(
            (c) => c.name.trim().toLowerCase() == name,
          );
          if (byName?.assignedRoute?.trim().isNotEmpty == true) {
            return byName!.assignedRoute!.trim();
          }
        }
        return null;
      }

      final effective = (raw == null || raw.isEmpty) ? customerRoute() : raw;
      if (effective == null || effective.isEmpty) return 'Unassigned';
      final route = routes.firstWhereOrNull(
        (r) => r.id == effective || r.name == effective,
      );
      return route?.name ?? effective;
    }

    final groups = <String, List<Order>>{};
    for (final o in filteredOrders) {
      final key = routeLabelFor(o);
      (groups[key] ??= []).add(o);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == 'Unassigned') return 1;
        if (b == 'Unassigned') return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    final widgets = <Widget>[];
    for (final key in sortedKeys) {
      final orders = groups[key]!;
      final count = orders.length;

      widgets.add(_RouteSectionHeader(title: key, count: count));
      for (final o in orders) {
        widgets.add(_buildOrderCard(o));
      }
      widgets.add(const SizedBox(height: 10));
    }
    return widgets;
  }

  Widget _buildFilters(
    List<DeliveryRoute> routes,
    List<String> availableRouteIds, {
    required bool routesLoaded,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildRouteChip(null, 'All Routes', routesLoaded: routesLoaded),
                _buildRouteChip(
                  '__unassigned__',
                  'Unassigned',
                  routesLoaded: routesLoaded,
                ),
                const SizedBox(width: 2),
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
                      return _buildRouteChip(
                        routeId,
                        route?.name ?? routeId,
                        routesLoaded: routesLoaded,
                      );
                    }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteChip(
    String? routeId,
    String label, {
    required bool routesLoaded,
  }) {
    final isLoading = routeId == 'loading';
    final isSelected = !isLoading && _selectedRouteId == routeId;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: (isLoading || (!routesLoaded && routeId != null))
            ? null
            : () {
                setState(() {
                  _selectedRouteId = isSelected ? null : routeId;
                });
              },
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
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : isLoading || (!routesLoaded && routeId != null)
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

  Future<void> _showFiltersSheet(BuildContext context) async {
    final res =
        await showModalBottomSheet<({bool clearAll, PaymentStatus? payment})?>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                PaymentStatus? payment = _selectedPaymentStatus;

                Widget chip(PaymentStatus? value, String label) {
                  final isSelected = value == payment;
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
                      payment = isSelected ? null : value;
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
                            chip(PaymentStatus.paid, 'Paid'),
                            chip(PaymentStatus.partial, 'Partial'),
                            chip(PaymentStatus.unpaid, 'Unpaid'),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.pop(context, (
                                    clearAll: true,
                                    payment: null,
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
                                  HapticFeedback.mediumImpact();
                                  Navigator.pop(context, (
                                    clearAll: false,
                                    payment: payment,
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
    });
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

  Widget _buildOrderCard(Order order) {
    final customerName = order.customerName.trim().isEmpty
        ? 'Unknown'
        : order.customerName.trim();
    final statusText = _humanStatus(order.status);

    final displayId = _displayOrderId(order.id);

    final typeLabel = order.orderType == OrderType.daily
        ? 'Daily'
        : 'One-time';

    final statusChipBg = switch (order.status) {
      OrderStatus.pending => const Color(0xFF6D5EF6),
      _ => _getStatusColor(order.status),
    };

    const statusChipFg = Colors.white;

    final lineTypes = order.items.length;
    final unitCount =
        order.items.fold<int>(0, (sum, i) => sum + i.quantity);
    final metaParts = <String>[
      DateFormat('EEE, d MMM').format(order.orderDate),
      if (lineTypes > 0)
        '$lineTypes ${lineTypes == 1 ? 'product' : 'products'}',
      if (unitCount > 0) '$unitCount units',
    ];
    final metaLine = metaParts.join(' · ');

    final payment = order.paymentStatus ?? PaymentStatus.unpaid;
    final paymentColor = _getPaymentColor(payment);
    final paymentLabel = switch (payment) {
      PaymentStatus.paid => 'Paid',
      PaymentStatus.partial => 'Partial',
      PaymentStatus.unpaid => 'Unpaid',
    };

    const previewMax = 3;
    final previewItems = order.items.take(previewMax).toList();
    final moreLines = order.items.length - previewItems.length;
    final detailsBody = previewItems.isEmpty
        ? '—'
        : previewItems
            .map(
              (i) =>
                  '${i.foodItemName} · ${_formatRupee(i.totalPrice)}',
            )
            .join('\n');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push('/owner/orders/${order.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: AppColors.primary.withValues(alpha: 0.1),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayId,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.45,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 0.15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  metaLine,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusChipBg,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: statusChipBg.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            statusText,
                            style: const TextStyle(
                              color: statusChipFg,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                              height: 1.1,
                              letterSpacing: 0.05,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 22,
                          color: AppColors.textLight.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                                  const Text(
                                    'Customer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    customerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _formatRupee(order.totalAmount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                    letterSpacing: -0.35,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text(
                              'Payment',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: paymentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: paymentColor.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Text(
                                paymentLabel,
                                style: TextStyle(
                                  color: paymentColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.border.withValues(alpha: 0.65),
                          ),
                        ),
                        Text(
                          'LINE ITEMS',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            color: AppColors.textLight,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 6),
                        previewItems.isEmpty
                            ? Text(
                                detailsBody,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.1,
                                  height: 1.35,
                                ),
                              )
                            : moreLines > 0
                            ? Text.rich(
                                TextSpan(
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.1,
                                    height: 1.35,
                                  ),
                                  children: [
                                    TextSpan(text: detailsBody),
                                    TextSpan(
                                      text: '\n+$moreLines more',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: AppColors.primary
                                            .withValues(alpha: 0.95),
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                detailsBody,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.1,
                                  height: 1.35,
                                ),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayOrderId(String rawId) {
    final id = rawId.trim();
    if (id.isEmpty) return '#ORD-—';
    final upper = id.toUpperCase();
    if (upper.startsWith('ORD-') || upper.startsWith('#ORD-')) {
      return upper.startsWith('#') ? upper : '#$upper';
    }
    final short = upper.length > 4 ? upper.substring(0, 4) : upper;
    return '#ORD-$short';
  }

  String _humanStatus(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Out for delivery';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusChipBg(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.successLighter.withValues(alpha: 0.85);
      case OrderStatus.confirmed:
        return AppColors.infoLighter.withValues(alpha: 0.85);
      case OrderStatus.preparing:
        return AppColors.secondary.withValues(alpha: 0.14);
      case OrderStatus.ready:
        return AppColors.primaryLighter.withValues(alpha: 0.75);
      case OrderStatus.delivered:
        return AppColors.backgroundTertiary.withValues(alpha: 0.8);
      case OrderStatus.cancelled:
        return AppColors.error.withValues(alpha: 0.12);
    }
  }

  Color _statusChipFg(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.success;
      case OrderStatus.confirmed:
        return AppColors.info;
      case OrderStatus.preparing:
        return AppColors.secondary;
      case OrderStatus.ready:
        return AppColors.primary;
      case OrderStatus.delivered:
        return AppColors.textSecondary;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }

  Color _getPaymentColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppColors.success;
      case PaymentStatus.partial:
        return AppColors.warning;
      case PaymentStatus.unpaid:
        return AppColors.error;
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return AppColors.warning;
      case OrderStatus.delivered:
        return AppColors.success;
      case OrderStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  Widget _buildEmptyState({required bool hasAnyOrders}) {
    return DeliveroEmptyState(
      title: hasAnyOrders ? 'No transactions found' : 'No orders yet',
      subtitle: hasAnyOrders
          ? 'Try adjusting your filters or search terms'
          : 'Create your first order to see it here.',
      icon: Icons.receipt_long_rounded,
      actionLabel: hasAnyOrders ? null : 'Create order',
      onActionPressed: hasAnyOrders
          ? null
          : () => context.push('/owner/orders/create'),
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

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Pill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InlineMeta({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaDivider extends StatelessWidget {
  const _MetaDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppColors.border,
    );
  }
}

class _RouteSectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _RouteSectionHeader({required this.title, required this.count});

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
              '$count ${count == 1 ? 'Order' : 'Orders'}',
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

class _OrdersTopBar extends StatelessWidget {
  const _OrdersTopBar();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: AppColors.backgroundPrimary,
      padding: EdgeInsets.fromLTRB(20, top + 18, 20, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Orders',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
