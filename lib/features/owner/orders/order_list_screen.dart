import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../app/providers.dart';
import '../../../app/reports_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/delivero_sliver_header.dart';
import '../../../core/widgets/primary_square_icon_button.dart';
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(
              Icons.print_rounded,
              size: 18,
              color: Colors.white,
            ),
            label: const Text(
              'PRINT',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
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
    final reports = ref.watch(reportsProvider);
    final bool noOrdersYet = orders.isEmpty;

    // Get unique route IDs from existing orders
    final availableRouteIds = orders
        .map((o) {
          final raw = o.assignedRoute?.trim();
          if (raw == null || raw.isEmpty) return null;
          final route = routes.firstWhereOrNull(
            (r) => r.id == raw || r.name == raw,
          );
          return route?.id ?? raw;
        })
        .whereType<String>()
        .toSet()
        .toList();

    if (routesLoaded &&
        _selectedRouteId != null &&
        !availableRouteIds.contains(_selectedRouteId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedRouteId = null);
      });
    }

    final filteredOrders = orders.where((order) {
      final matchesSearch =
          order.customerName.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          order.id.toLowerCase().contains(_searchQuery.toLowerCase());

      // Handle both ID and name for assignedRoute
      final route = routes.firstWhereOrNull(
        (r) => r.id == order.assignedRoute || r.name == order.assignedRoute,
      );
      final selectedRouteId = routesLoaded ? _selectedRouteId : null;
      final matchesRoute =
          selectedRouteId == null ||
          order.assignedRoute == selectedRouteId ||
          route?.id == selectedRouteId;

      return matchesSearch && matchesRoute;
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
      body: RefreshIndicator(
        onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            if (!noOrdersYet) ...[
              DeliveroSliverHeader(
                title: 'Orders',
                subtitle: '${orders.length} transactions processed',
                expandedHeight: 140,
                floating: true,
                pinned: true,
                backgroundGradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.14),
                    AppColors.secondary.withValues(alpha: 0.10),
                    AppColors.backgroundPrimary,
                  ],
                ),
                actions: [
                  PrimarySquareIconButton(
                    icon: Icons.add_rounded,
                    color: AppColors.secondary,
                    onPressed: () => context.push('/owner/orders/create'),
                  ),
                  if (filteredOrders.isNotEmpty)
                    IconButton(
                      tooltip: 'Print pack list',
                      onPressed: () => _showPackagingSummary(filteredOrders),
                      icon: const Icon(
                        Icons.print_rounded,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  const SizedBox(width: 16),
                ],
              ),
              SliverToBoxAdapter(
                child: _buildQuickStats(reports, filteredOrders),
              ),
              SliverToBoxAdapter(
                child: _buildFilters(
                  routes,
                  availableRouteIds,
                  routesLoaded: routesLoaded,
                ),
              ),
            ],
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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final order = filteredOrders[index];
                    return _buildOrderCard(order);
                  }, childCount: filteredOrders.length),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(ReportsData reports, List<Order> filteredOrders) {
    final pendingCount = filteredOrders
        .where((o) => o.status == OrderStatus.pending)
        .length;
    final deliveredCount = filteredOrders
        .where((o) => o.status == OrderStatus.delivered)
        .length;
    final totalValue = filteredOrders.fold<double>(
      0,
      (sum, o) => sum + o.totalAmount,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Revenue',
                  '₹${NumberFormat.compact().format(totalValue)}',
                  AppColors.primary,
                  Icons.currency_rupee_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Orders Today',
                  filteredOrders
                      .where((o) {
                        final d = o.orderDate;
                        final now = DateTime.now();
                        return d.year == now.year &&
                            d.month == now.month &&
                            d.day == now.day;
                      })
                      .length
                      .toString(),
                  AppColors.secondary,
                  Icons.today_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  pendingCount.toString(),
                  AppColors.warning,
                  Icons.schedule_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Fulfilled',
                  deliveredCount.toString(),
                  AppColors.success,
                  Icons.check_circle_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final Color tint;
    if (color == AppColors.primary) {
      tint = AppColors.primaryLighter;
    } else if (color == AppColors.success) {
      tint = AppColors.successLighter;
    } else if (color == AppColors.warning) {
      tint = AppColors.warningLighter;
    } else {
      tint = AppColors.backgroundSecondary;
    }

    return Container(
      height: 86,
      padding: const EdgeInsets.all(12),
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
              color: tint.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textLight,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(
    List<DeliveryRoute> routes,
    List<String> availableRouteIds, {
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
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search by ID or Customer...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textLight,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Routes',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textLight,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildRouteChip(
                        null,
                        'All Routes',
                        routesLoaded: routesLoaded,
                      ),
                      if (!routesLoaded && routes.isEmpty)
                        _buildRouteChip(
                          'loading',
                          'Loading…',
                          routesLoaded: routesLoaded,
                        ),
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
                            return _buildRouteChip(
                              routeId,
                              route?.name ?? 'Unknown Route',
                              routesLoaded: routesLoaded,
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

  Widget _buildRouteChip(
    String? routeId,
    String label, {
    required bool routesLoaded,
  }) {
    final isLoading = routeId == 'loading';
    final selectedRouteId = routesLoaded ? _selectedRouteId : null;
    final isSelected = !isLoading && selectedRouteId == routeId;
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

  Widget _buildOrderCard(Order order) {
    final drivers = ref.watch(driversProvider);
    final routes = ref.watch(routesProvider);

    final statusColor = _getStatusColor(order.status);
    final paymentStatus = order.paymentStatus ?? PaymentStatus.unpaid;
    final paymentColor = _getPaymentColor(paymentStatus);
    final itemCount = order.items.fold(0, (sum, item) => sum + item.quantity);
    final shortId =
        (order.id.trim().isEmpty
                ? '--------'
                : (order.id.length > 8 ? order.id.substring(0, 8) : order.id))
            .toUpperCase();
    final orderDateLabel = DateFormat('MMM d • h:mm a').format(order.orderDate);
    final driver = drivers.firstWhereOrNull(
      (d) => d.id == order.assignedDriver,
    );
    final driverLabel =
        driver?.name ??
        (order.assignedDriver?.trim().isNotEmpty == true
            ? order.assignedDriver!.trim()
            : 'Unassigned');
    final route = routes.firstWhereOrNull(
      (r) => r.id == order.assignedRoute || r.name == order.assignedRoute,
    );
    final routeLabel =
        route?.name ??
        (order.assignedRoute?.trim().isNotEmpty == true
            ? order.assignedRoute!.trim()
            : 'Unassigned');

    final unitsLabel = '$itemCount U';
    final statusLabel = switch (order.status) {
      OrderStatus.pending => 'PEND',
      OrderStatus.confirmed => 'CONF',
      OrderStatus.preparing => 'PREP',
      OrderStatus.ready => 'READY',
      OrderStatus.delivered => 'DLVD',
      OrderStatus.cancelled => 'CNCL',
    };
    final paymentLabel = switch (paymentStatus) {
      PaymentStatus.paid => 'PAID',
      PaymentStatus.partial => 'PART',
      PaymentStatus.unpaid => 'DUE',
    };

    final previewItems = [...order.items]
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    final shownItems = previewItems.take(2).toList();
    final remainingItems = (previewItems.length - shownItems.length).clamp(
      0,
      999,
    );
    final customerLabel = order.customerName.trim().isEmpty
        ? 'Unknown Customer'
        : order.customerName;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border(
          left: BorderSide(color: statusColor.withValues(alpha: 0.9), width: 3),
          top: const BorderSide(color: AppColors.border),
          right: const BorderSide(color: AppColors.border),
          bottom: const BorderSide(color: AppColors.border),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/owner/orders/${order.id}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '#$shortId',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              orderDateLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '₹${NumberFormat.decimalPattern().format(order.totalAmount)}',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        customerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 2,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '$routeLabel  →  $driverLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.restaurant_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                shownItems.isEmpty
                                    ? 'No items'
                                    : shownItems
                                          .map(
                                            (i) => i.quantity > 1
                                                ? '${i.foodItemName} ×${i.quantity}'
                                                : i.foodItemName,
                                          )
                                          .join('  •  '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            if (remainingItems > 0) ...[
                              const SizedBox(width: 10),
                              Text(
                                '+$remainingItems more',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _InlineMeta(
                                icon: Icons.inventory_2_outlined,
                                label: unitsLabel,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const _MetaDivider(),
                            Expanded(
                              child: _InlineMeta(
                                icon: Icons.local_shipping_outlined,
                                label: statusLabel,
                                color: statusColor,
                              ),
                            ),
                            const _MetaDivider(),
                            Expanded(
                              child: _InlineMeta(
                                icon: Icons.payments_outlined,
                                label: paymentLabel,
                                color: paymentColor,
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
          ],
        ),
      ),
    );
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
    final title = hasAnyOrders ? 'No transactions found' : 'No orders yet';
    final subtitle = hasAnyOrders
        ? 'Try adjusting your filters or search terms'
        : 'Create your first order to see it here.';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: AppColors.textLight,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (!hasAnyOrders) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 220,
              child: FilledButton.icon(
                onPressed: () => context.push('/owner/orders/create'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'Create order',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ],
        ],
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
