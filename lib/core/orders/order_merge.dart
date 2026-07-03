import 'package:collection/collection.dart';

import '../../data/models/order.dart';
import 'business_day.dart';

/// Finds an open order to append items into (same customer, type, business day, and run).
Order? findMergeTargetOrder({
  required List<Order> orders,
  required String customerId,
  required OrderType orderType,
  required DeliveryRun deliveryRun,
  required DateTime referenceTime,
  int rolloverHour = kDefaultBusinessDayRolloverHour,
  bool forDriver = false,
}) {
  if (forDriver) return null;
  if (orderType == OrderType.special) return null;

  final candidates = orders.where((o) {
    if (o.customerId != customerId) return false;
    if (o.orderType != orderType) return false;
    if (o.deliveryRun != deliveryRun) return false;
    if (!isSameBusinessDay(
      o.orderDate,
      referenceTime,
      rolloverHour: rolloverHour,
    )) {
      return false;
    }
    if (!canModifyOrderItems(
      o,
      referenceTime: referenceTime,
      rolloverHour: rolloverHour,
    )) {
      return false;
    }
    if (o.status != OrderStatus.pending) return false;
    return true;
  }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  return candidates.firstOrNull;
}
