import '../../data/models/delivery_route.dart';
import '../../data/models/order.dart';
import '../utils/route_refs.dart';

/// One aggregated product row for kitchen / packing.
class ProductionLineSummary {
  final String productName;
  final String? foodItemId;
  final int totalUnits;
  final int orderLineCount;
  final Map<int, int> packBreakdown;

  const ProductionLineSummary({
    required this.productName,
    this.foodItemId,
    required this.totalUnits,
    required this.orderLineCount,
    required this.packBreakdown,
  });
}

/// Aggregated production list for a scoped set of orders.
class ProductionSummary {
  final DateTime scopeDay;
  final String? routeLabel;
  final int totalOrdersInScope;
  final int activeOrders;
  final int totalUnits;
  final Map<OrderType, int> ordersByType;
  final List<ProductionLineSummary> lines;

  const ProductionSummary({
    required this.scopeDay,
    this.routeLabel,
    required this.totalOrdersInScope,
    required this.activeOrders,
    required this.totalUnits,
    required this.ordersByType,
    required this.lines,
  });

  bool get isEmpty => lines.isEmpty;
}

class ProductionSummaryScope {
  final DateTime day;
  final String? routeId;
  final List<DeliveryRoute> routes;
  final String? routeLabel;

  const ProductionSummaryScope({
    required this.day,
    this.routeId,
    this.routes = const [],
    this.routeLabel,
  });
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _orderMatchesRoute(Order order, String? routeId, List<DeliveryRoute> routes) {
  if (routeId == null || routeId.trim().isEmpty) return true;
  final resolved = RouteRefs.routeIdForRef(order.assignedRoute, routes);
  return resolved == routeId.trim();
}

List<Order> filterOrdersForProduction(
  List<Order> orders,
  ProductionSummaryScope scope,
) {
  return orders.where((order) {
    if (!_isSameCalendarDay(order.orderDate, scope.day)) return false;
    if (order.status == OrderStatus.cancelled) return false;
    if (!_orderMatchesRoute(order, scope.routeId, scope.routes)) return false;
    return true;
  }).toList();
}

ProductionSummary buildProductionSummary(
  List<Order> orders,
  ProductionSummaryScope scope,
) {
  final scoped = filterOrdersForProduction(orders, scope);
  final ordersByType = <OrderType, int>{};
  final lineMap = <String, _LineAccumulator>{};

  for (final order in scoped) {
    ordersByType[order.orderType] = (ordersByType[order.orderType] ?? 0) + 1;
    for (final item in order.items) {
      if (item.quantity <= 0) continue;
      final key = item.foodItemId.isNotEmpty
          ? item.foodItemId
          : item.foodItemName.trim().toLowerCase();
      final acc = lineMap.putIfAbsent(
        key,
        () => _LineAccumulator(
          productName: item.foodItemName.trim().isEmpty
              ? 'Unknown item'
              : item.foodItemName.trim(),
          foodItemId: item.foodItemId.isNotEmpty ? item.foodItemId : null,
        ),
      );
      acc.totalUnits += item.quantity;
      acc.orderLineCount += 1;
      acc.packBreakdown[item.quantity] =
          (acc.packBreakdown[item.quantity] ?? 0) + 1;
    }
  }

  final lines = lineMap.values
      .map(
        (acc) => ProductionLineSummary(
          productName: acc.productName,
          foodItemId: acc.foodItemId,
          totalUnits: acc.totalUnits,
          orderLineCount: acc.orderLineCount,
          packBreakdown: Map.unmodifiable(acc.packBreakdown),
        ),
      )
      .toList()
    ..sort(
      (a, b) =>
          a.productName.toLowerCase().compareTo(b.productName.toLowerCase()),
    );

  final totalUnits = lines.fold<int>(0, (sum, line) => sum + line.totalUnits);

  return ProductionSummary(
    scopeDay: scope.day,
    routeLabel: scope.routeLabel,
    totalOrdersInScope: scoped.length,
    activeOrders: scoped.length,
    totalUnits: totalUnits,
    ordersByType: Map.unmodifiable(ordersByType),
    lines: lines,
  );
}

class _LineAccumulator {
  final String productName;
  final String? foodItemId;
  int totalUnits = 0;
  int orderLineCount = 0;
  final Map<int, int> packBreakdown = {};

  _LineAccumulator({required this.productName, this.foodItemId});
}

/// One row per pack size, largest quantity first (e.g. "5 × 20 units").
List<String> formatPackBreakdownLines(Map<int, int> packBreakdown) {
  if (packBreakdown.isEmpty) return const [];
  final entries = packBreakdown.entries.toList()
    ..sort((a, b) => b.key.compareTo(a.key));
  return [
    for (final e in entries) '${e.value} × ${e.key} units',
  ];
}

String formatProductionLine(ProductionLineSummary line) {
  final buffer = StringBuffer(
    '${line.productName.toUpperCase()} — ${line.totalUnits} units total',
  );
  for (final row in formatPackBreakdownLines(line.packBreakdown)) {
    buffer.writeln('  $row');
  }
  return buffer.toString().trim();
}

String formatProductionSummaryText(ProductionSummary summary) {
  final dayLabel = _formatDay(summary.scopeDay);
  final buffer = StringBuffer('Production list — $dayLabel\n');
  if (summary.routeLabel != null && summary.routeLabel!.trim().isNotEmpty) {
    buffer.writeln('Route: ${summary.routeLabel!.trim()}');
  }
  buffer.writeln(
    'Orders: ${summary.activeOrders} | Products: ${summary.lines.length} | '
    'Total units: ${summary.totalUnits}',
  );

  if (summary.ordersByType.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('By order type:');
    for (final type in OrderType.values) {
      final count = summary.ordersByType[type];
      if (count == null || count == 0) continue;
      buffer.writeln('  · ${_orderTypeLabel(type)}: $count');
    }
  }

  if (summary.lines.isEmpty) {
    buffer.writeln('\nNo items in scope.');
    return buffer.toString().trim();
  }

  buffer.writeln();
  for (final line in summary.lines) {
    buffer.writeln(formatProductionLine(line));
    buffer.writeln();
  }
  return buffer.toString().trim();
}

String _formatDay(DateTime day) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${day.day} ${months[day.month - 1]} ${day.year}';
}

String _orderTypeLabel(OrderType type) {
  return switch (type) {
    OrderType.daily => 'Daily',
    OrderType.oneTime => 'One-time',
    OrderType.special => 'Special',
  };
}
