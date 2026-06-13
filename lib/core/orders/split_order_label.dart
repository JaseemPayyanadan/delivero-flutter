import '../../data/models/order.dart';
import 'business_day.dart';
import 'order_sort.dart';

/// Subtitle when multiple orders share customer, run, and business day (split boxes).
String? splitBoxSubtitle(
  Order order,
  List<Order> allOrders, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  if (order.orderType == OrderType.special) return null;
  if (order.status == OrderStatus.cancelled) return null;

  final dayKey = businessDayKey(order.orderDate, rolloverHour: rolloverHour);
  final siblings = allOrders
      .where(
        (o) =>
            o.customerId == order.customerId &&
            o.deliveryRun == order.deliveryRun &&
            o.orderType == order.orderType &&
            o.status != OrderStatus.cancelled &&
            businessDayKey(o.orderDate, rolloverHour: rolloverHour) == dayKey,
      )
      .toList()
    ..sort((a, b) => compareOrdersByDate(a, b, newestFirst: false));

  if (siblings.length < 2) return null;
  final idx = siblings.indexWhere((o) => o.id == order.id);
  if (idx < 0) return null;
  return 'Box ${idx + 1} of ${siblings.length}';
}
