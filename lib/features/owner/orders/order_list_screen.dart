import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
import '../../../core/ui/ui_kit.dart';
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
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 140.0,
            floating: true,
            pinned: true,
            backgroundColor: AppColors.backgroundPrimary,
            elevation: 0,
            actions: [
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
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 16,
              ),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Orders',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    '${orders.length} transactions processed',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildQuickStats(reports, filteredOrders)),
          SliverToBoxAdapter(child: _buildFilters(routes, availableRouteIds)),
          if (filteredOrders.isEmpty)
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
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'owner_orders_fab',
        onPressed: () => context.push('/owner/orders/create'),
        backgroundColor: AppColors.primary,
        elevation: 2,
        icon: const Icon(CupertinoIcons.add, color: Colors.white),
        label: const Text(
          'New Order',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        shape: const StadiumBorder(),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'TOTAL ORDERS',
              filteredOrders.length.toString(),
              AppColors.primary,
              Icons.receipt_long_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'PENDING',
              pendingCount.toString(),
              AppColors.warning,
              Icons.schedule_rounded,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'FULFILLED',
              deliveredCount.toString(),
              AppColors.success,
              Icons.check_circle_rounded,
            ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textLight,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
              ),
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
          UiPillTextField(
            controller: _searchController,
            hintText: 'Search shipments & orders',
            onChanged: (val) => setState(() => _searchQuery = val),
            onClear: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
            prefixIcon: CupertinoIcons.search,
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
    final dateStr = DateFormat('MMM d, yyyy').format(order.orderDate);
    final timeStr = DateFormat('hh:mm a').format(order.orderDate);
    final statusColor = _getStatusColor(order.status);
    final paymentStatus = order.paymentStatus ?? PaymentStatus.unpaid;
    final paymentColor = _getPaymentColor(paymentStatus);
    final itemCount = order.items.fold(0, (sum, item) => sum + item.quantity);
    final progressIndex = _getProgressIndex(order.status);
    final statusLabel = _getStatusLabel(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => context.push('/owner/orders/${order.id}'),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundSecondary,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  '#${order.id.substring(0, 8).toUpperCase()}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: _StatusBadge(
                            label: statusLabel,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _OrderProgressStepper(
                      activeIndex: progressIndex,
                      isCancelled: order.status == OrderStatus.cancelled,
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
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 14,
                          color: AppColors.textLight,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$dateStr • $timeStr',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            '$itemCount ${itemCount == 1 ? 'UNIT' : 'UNITS'}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _OrderMetaBlock(
                            label: 'Recipient',
                            value: order.customerName,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OrderMetaBlock(
                            label: 'Address',
                            value: order.customerAddress,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.backgroundPrimary,
                  border: const Border(
                    top: BorderSide(color: AppColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PAYMENT SETTLEMENT',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textLight,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: paymentColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: paymentColor.withValues(
                                        alpha: 0.3,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                order.paymentMethod == PaymentMethod.upi
                                    ? Icons.account_balance_wallet_rounded
                                    : Icons.payments_rounded,
                                size: 12,
                                color: paymentColor.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  paymentStatus.name.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: paymentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'TRANSACTION TOTAL',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textLight,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '₹${NumberFormat.decimalPattern().format(order.totalAmount)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _getProgressIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return 2;
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return 1;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.pending:
      case OrderStatus.cancelled:
        return 0;
    }
  }

  String _getStatusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.delivered:
        return 'DELIVERED';
      case OrderStatus.cancelled:
        return 'CANCELLED';
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.confirmed:
        return 'IN DELIVERY';
      case OrderStatus.pending:
        return 'PICKED UP';
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

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _OrderMetaBlock extends StatelessWidget {
  final String label;
  final String value;

  const _OrderMetaBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
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
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

class _OrderProgressStepper extends StatelessWidget {
  final int activeIndex;
  final bool isCancelled;

  const _OrderProgressStepper({
    required this.activeIndex,
    required this.isCancelled,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isCancelled ? AppColors.textDisabled : AppColors.primary;
    final inactiveColor = AppColors.border;
    final textColor =
        isCancelled ? AppColors.textLight : AppColors.textSecondary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final progress = (activeIndex.clamp(0, 2)) / 2;
        return SizedBox(
          height: 44,
          child: Stack(
            children: [
              Positioned(
                left: 14,
                right: 14,
                top: 8,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: inactiveColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                left: 14,
                top: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Container(
                    height: 2,
                    width: (constraints.maxWidth - 28) * progress,
                    color: activeColor,
                  ),
                ),
              ),
              Row(
                children: [
                  _StepDot(
                    label: 'Picked up',
                    isActive: activeIndex >= 0 && !isCancelled,
                    activeColor: activeColor,
                    textColor: textColor,
                  ),
                  _StepDot(
                    label: 'In Delivery',
                    isActive: activeIndex >= 1 && !isCancelled,
                    activeColor: activeColor,
                    textColor: textColor,
                  ),
                  _StepDot(
                    label: 'Delivered',
                    isActive: activeIndex >= 2 && !isCancelled,
                    activeColor: activeColor,
                    textColor: textColor,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color textColor;

  const _StepDot({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isActive ? activeColor : AppColors.border;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: dotColor, width: 2),
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
