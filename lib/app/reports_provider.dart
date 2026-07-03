import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/order.dart';
import '../data/models/product_unit.dart';
import 'providers.dart';

class ReportsData {
  final double totalRevenue;
  final double totalPendingRevenue;
  final int totalOrders;
  final int completedOrders;
  final int pendingOrders;
  final int cancelledOrders;
  final Map<String, double> paymentMethodBreakdown;
  final Map<String, int> orderStatusBreakdown;
  final List<DailySalesData> dailySales;
  final double averageOrderValue;
  final Map<String, ProductSalesData> productSales;
  final Map<String, CustomerRevenueData> customerRevenue;

  ReportsData({
    required this.totalRevenue,
    required this.totalPendingRevenue,
    required this.totalOrders,
    required this.completedOrders,
    required this.pendingOrders,
    required this.cancelledOrders,
    required this.paymentMethodBreakdown,
    required this.orderStatusBreakdown,
    required this.dailySales,
    required this.averageOrderValue,
    required this.productSales,
    required this.customerRevenue,
  });

  factory ReportsData.empty() => ReportsData(
    totalRevenue: 0,
    totalPendingRevenue: 0,
    totalOrders: 0,
    completedOrders: 0,
    pendingOrders: 0,
    cancelledOrders: 0,
    paymentMethodBreakdown: {},
    orderStatusBreakdown: {},
    dailySales: [],
    averageOrderValue: 0,
    productSales: {},
    customerRevenue: {},
  );
}

class ProductSalesData {
  final String name;
  final int quantity;
  final double revenue;
  final ProductUnit unit;

  ProductSalesData({
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.unit,
  });
}

class CustomerRevenueData {
  final String name;
  final double revenue;
  final int orderCount;

  CustomerRevenueData({
    required this.name,
    required this.revenue,
    required this.orderCount,
  });
}

class DailySalesData {
  final DateTime date;
  final double amount;
  final int count;

  DailySalesData({
    required this.date,
    required this.amount,
    required this.count,
  });
}

/// Computes a [ReportsData] snapshot from [orders]. Extracted so both the
/// provider (all-time) and the reports screen (date-filtered) share one
/// implementation.
ReportsData computeReports(List<Order> orders) {
  if (orders.isEmpty) return ReportsData.empty();

  double totalRevenue = 0;
  double totalPendingRevenue = 0;
  int completedOrders = 0;
  int pendingOrders = 0;
  int cancelledOrders = 0;
  Map<String, double> paymentMethodBreakdown = {};
  Map<String, int> orderStatusBreakdown = {};
  Map<DateTime, DailySalesData> dailyMap = {};
  Map<String, ProductSalesData> productSalesMap = {};
  Map<String, CustomerRevenueData> customerRevenueMap = {};

  for (var order in orders) {
    if (order.paymentStatus == PaymentStatus.paid) {
      totalRevenue += order.totalAmount;
    } else if (order.paymentStatus == PaymentStatus.partial) {
      totalRevenue += (order.amountPaid ?? 0);
      totalPendingRevenue += (order.totalAmount - (order.amountPaid ?? 0));
    } else {
      totalPendingRevenue += order.totalAmount;
    }

    if (order.status == OrderStatus.delivered) {
      completedOrders++;
    } else if (order.status == OrderStatus.pending) {
      pendingOrders++;
    } else if (order.status == OrderStatus.cancelled) {
      cancelledOrders++;
    }

    // Payment breakdown
    final pm = order.paymentMethod?.name ?? 'unknown';
    paymentMethodBreakdown[pm] =
        (paymentMethodBreakdown[pm] ?? 0) + order.totalAmount;

    // Status breakdown
    final status = order.status.name;
    orderStatusBreakdown[status] = (orderStatusBreakdown[status] ?? 0) + 1;

    // Product breakdown
    for (var item in order.items) {
      final existing = productSalesMap[item.foodItemName];
      if (existing != null) {
        productSalesMap[item.foodItemName] = ProductSalesData(
          name: item.foodItemName,
          quantity: existing.quantity + item.quantity,
          revenue: existing.revenue + item.totalPrice,
          unit: existing.unit,
        );
      } else {
        productSalesMap[item.foodItemName] = ProductSalesData(
          name: item.foodItemName,
          quantity: item.quantity,
          revenue: item.totalPrice,
          unit: item.unit,
        );
      }
    }

    // Customer revenue — keyed by customerId to prevent name-mismatch duplicates
    final custKey = order.customerId.isNotEmpty
        ? order.customerId
        : order.customerName;
    final custExisting = customerRevenueMap[custKey];
    if (custExisting != null) {
      customerRevenueMap[custKey] = CustomerRevenueData(
        name: order.customerName,
        revenue: custExisting.revenue + order.totalAmount,
        orderCount: custExisting.orderCount + 1,
      );
    } else {
      customerRevenueMap[custKey] = CustomerRevenueData(
        name: order.customerName,
        revenue: order.totalAmount,
        orderCount: 1,
      );
    }

    // Daily aggregation
    final date = DateTime(
      order.orderDate.year,
      order.orderDate.month,
      order.orderDate.day,
    );
    if (dailyMap.containsKey(date)) {
      final existing = dailyMap[date]!;
      dailyMap[date] = DailySalesData(
        date: date,
        amount: existing.amount + order.totalAmount,
        count: existing.count + 1,
      );
    } else {
      dailyMap[date] = DailySalesData(
        date: date,
        amount: order.totalAmount,
        count: 1,
      );
    }
  }

  final dailySales = dailyMap.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final avgOrderValue = totalRevenue / (orders.isEmpty ? 1 : orders.length);

  return ReportsData(
    totalRevenue: totalRevenue,
    totalPendingRevenue: totalPendingRevenue,
    totalOrders: orders.length,
    completedOrders: completedOrders,
    pendingOrders: pendingOrders,
    cancelledOrders: cancelledOrders,
    paymentMethodBreakdown: paymentMethodBreakdown,
    orderStatusBreakdown: orderStatusBreakdown,
    dailySales: dailySales,
    averageOrderValue: avgOrderValue,
    productSales: productSalesMap,
    customerRevenue: customerRevenueMap,
  );
}

final reportsProvider = Provider<ReportsData>((ref) {
  return computeReports(ref.watch(ordersProvider));
});
