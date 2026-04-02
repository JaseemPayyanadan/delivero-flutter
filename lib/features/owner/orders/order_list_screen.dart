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
                      'PACKAGING MANIFEST',
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
                        'ITEM',
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
                        'PACK BREAKDOWN',
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
    final reports = ref.watch(reportsProvider);

    // Get unique route IDs from existing orders
    final availableRouteIds = orders
        .map((o) {
          final route = routes.firstWhereOrNull(
            (r) => r.id == o.assignedRoute || r.name == o.assignedRoute,
          );
          return route?.id;
        })
        .whereType<String>()
        .toSet()
        .toList();

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
      final matchesRoute =
          _selectedRouteId == null ||
          order.assignedRoute == _selectedRouteId ||
          route?.id == _selectedRouteId;

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
            DeliveroSliverHeader(
              title: 'Orders',
              subtitle: '${orders.length} transactions processed',
              expandedHeight: 140,
              floating: true,
              pinned: true,
              actions: [
                IconButton(
                  onPressed: () => context.push('/owner/orders/create'),
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 12,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                if (filteredOrders.isNotEmpty)
                  IconButton(
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
            SliverToBoxAdapter(child: _buildFilters(routes, availableRouteIds)),
            if (!ordersLoaded && orders.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredOrders.isEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: _buildEmptyState(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
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
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 22, color: color),
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
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                    letterSpacing: -0.4,
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
    List<String> availableRouteIds,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
              fillColor: AppColors.surface,
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
          const SizedBox(height: 24),
          const Text(
            'LOGISTICS ROUTES',
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
                _buildRouteChip(null, 'All Routes'),
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

  Widget _buildRouteChip(String? routeId, String label) {
    final isSelected = _selectedRouteId == routeId;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) =>
            setState(() => _selectedRouteId = val ? routeId : null),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : AppColors.textPrimary,
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
        ),
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final drivers = ref.watch(driversProvider);

    final statusColor = _getStatusColor(order.status);
    final paymentStatus = order.paymentStatus ?? PaymentStatus.unpaid;
    final paymentColor = _getPaymentColor(paymentStatus);
    final itemCount = order.items.fold(0, (sum, item) => sum + item.quantity);
    final shortId = order.id.substring(0, 8).toUpperCase();
    final hasNotes = (order.notes ?? '').trim().isNotEmpty;
    final address = order.customerAddress.trim().isEmpty
        ? 'Address not available'
        : order.customerAddress.trim();
    final orderDateLabel = DateFormat('MMM d • h:mm a').format(order.orderDate);
    final driver = drivers.firstWhereOrNull(
      (d) => d.id == order.assignedDriver,
    );
    final driverLabel =
        driver?.name ??
        (order.assignedDriver?.trim().isNotEmpty == true
            ? order.assignedDriver!.trim()
            : 'Unassigned');
    final isOneTime = order.orderType == OrderType.oneTime;
    final orderTypeBannerText = isOneTime
        ? 'One-time order for ${order.customerName}'
        : 'Daily order for ${order.customerName}';
    final orderTypeIcon = isOneTime
        ? Icons.bolt_rounded
        : Icons.calendar_today_rounded;
    final orderTypeAccent = isOneTime ? AppColors.warning : AppColors.success;
    final orderTypeBg = isOneTime
        ? AppColors.warningLighter.withValues(alpha: 0.6)
        : AppColors.successLighter.withValues(alpha: 0.6);

    final previewItems = [...order.items]
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    final shownItems = previewItems.take(3).toList();
    final remainingItems = (previewItems.length - shownItems.length).clamp(
      0,
      999,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => context.push('/owner/orders/${order.id}'),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(12),
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
                                color: AppColors.textLight,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '₹${NumberFormat.decimalPattern().format(order.totalAmount)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        order.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.near_me_outlined,
                            size: 16,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.person_pin_circle_outlined,
                            size: 16,
                            color: AppColors.textLight,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              driverLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              if (shownItems.isEmpty)
                                _InfoChip(
                                  icon: Icons.fastfood_rounded,
                                  label: 'No items',
                                )
                              else ...[
                                for (final item in shownItems) ...[
                                  _InfoChip(
                                    icon: Icons.fastfood_rounded,
                                    label: item.quantity > 1
                                        ? '${item.foodItemName} ×${item.quantity}'
                                        : item.foodItemName,
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                if (remainingItems > 0)
                                  _InfoChip(
                                    icon: Icons.more_horiz_rounded,
                                    label: '+$remainingItems more',
                                  )
                                else
                                  const SizedBox.shrink(),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _FeatureColumn(
                                icon: Icons.inventory_2_outlined,
                                value: '$itemCount Units',
                              ),
                            ),
                            const _FeatureDivider(),
                            Expanded(
                              child: _FeatureColumn(
                                icon: Icons.local_shipping_outlined,
                                value: order.status.name.toUpperCase(),
                                valueColor: statusColor,
                              ),
                            ),
                            const _FeatureDivider(),
                            Expanded(
                              child: _FeatureColumn(
                                icon: Icons.payments_outlined,
                                value: paymentStatus.name.toUpperCase(),
                                valueColor: paymentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasNotes) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 16,
                              color: AppColors.textLight,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                order.notes!.trim(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: orderTypeBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              orderTypeIcon,
                              size: 18,
                              color: orderTypeAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                orderTypeBannerText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: orderTypeAccent,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.1,
                                ),
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

  Widget _buildEmptyState() {
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
          const Text(
            'No transactions recorded',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(icon, size: 13, color: AppColors.textLight),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color? valueColor;

  const _FeatureColumn({
    required this.icon,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: AppColors.textLight),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor ?? AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _FeatureDivider extends StatelessWidget {
  const _FeatureDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: AppColors.border,
    );
  }
}
