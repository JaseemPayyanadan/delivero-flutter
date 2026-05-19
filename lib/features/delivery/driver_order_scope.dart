import '../../data/models/order.dart';

bool canDriverAccessOrder(
  Order order, {
  required String? driverId,
  required String? routeId,
}) {
  final normalizedDriverId = driverId?.trim();
  if (normalizedDriverId == null || normalizedDriverId.isEmpty) {
    return false;
  }

  final assignedDriver = order.assignedDriver?.trim();
  if (assignedDriver != null &&
      assignedDriver.isNotEmpty &&
      assignedDriver == normalizedDriverId) {
    return true;
  }

  final normalizedRouteId = routeId?.trim();
  if (normalizedRouteId == null || normalizedRouteId.isEmpty) {
    return false;
  }

  final assignedRoute = order.assignedRoute?.trim();
  return assignedRoute != null &&
      assignedRoute.isNotEmpty &&
      assignedRoute == normalizedRouteId;
}

List<Order> driverScopedOrders(
  Iterable<Order> orders, {
  required String? driverId,
  required String? routeId,
}) {
  return orders
      .where(
        (order) =>
            canDriverAccessOrder(order, driverId: driverId, routeId: routeId),
      )
      .toList();
}

bool isDriverActiveOrder(Order order) {
  switch (order.status) {
    case OrderStatus.delivered:
    case OrderStatus.cancelled:
      return false;
    case OrderStatus.pending:
    case OrderStatus.confirmed:
    case OrderStatus.preparing:
    case OrderStatus.ready:
      return true;
  }
}
