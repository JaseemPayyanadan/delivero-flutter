import 'dart:async';

import 'package:collection/collection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/customer.dart';
import '../../data/models/order.dart';
import 'business_day.dart';

const int kMaxBackfillBusinessDays = 7;

/// Outcome of a rollover batch or sync pass.
class DailyOrderRecreationResult {
  final int createdCount;
  final int syncedCount;
  final int cancelledCount;
  final List<String> createdOrderIds;

  const DailyOrderRecreationResult({
    this.createdCount = 0,
    this.syncedCount = 0,
    this.cancelledCount = 0,
    this.createdOrderIds = const [],
  });

  DailyOrderRecreationResult merge(DailyOrderRecreationResult other) {
    return DailyOrderRecreationResult(
      createdCount: createdCount + other.createdCount,
      syncedCount: syncedCount + other.syncedCount,
      cancelledCount: cancelledCount + other.cancelledCount,
      createdOrderIds: [...createdOrderIds, ...other.createdOrderIds],
    );
  }

  bool get hasChanges =>
      createdCount > 0 || syncedCount > 0 || cancelledCount > 0;
}

class DailyOrderRecreationPrefs {
  DailyOrderRecreationPrefs._();

  static String lastRunKey(String factoryId) =>
      'factory_${factoryId}_lastDailyRecreationDay';

  static String autoRecreateKey(String factoryId) =>
      'factory_${factoryId}_autoRecreateDaily';

  static Future<bool> isAutoRecreateEnabled(String factoryId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(autoRecreateKey(factoryId)) ?? true;
  }

  static Future<void> setAutoRecreateEnabled(
    String factoryId,
    bool enabled,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(autoRecreateKey(factoryId), enabled);
  }

  static Future<DateTime?> loadLastRunDay(String factoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(lastRunKey(factoryId));
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  static Future<void> saveLastRunDay(
    String factoryId,
    DateTime businessDayKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = DateTime(
      businessDayKey.year,
      businessDayKey.month,
      businessDayKey.day,
    );
    final raw =
        '${key.year.toString().padLeft(4, '0')}-'
        '${key.month.toString().padLeft(2, '0')}-'
        '${key.day.toString().padLeft(2, '0')}';
    await prefs.setString(lastRunKey(factoryId), raw);
  }
}

const _unresolvedStatuses = {
  OrderStatus.pending,
  OrderStatus.confirmed,
  OrderStatus.preparing,
  OrderStatus.ready,
};

/// Returns daily orders on [sourceBusinessDay] that were never delivered
/// or cancelled — i.e. still need the owner to act on them.
List<Order> findUnresolvedSourceOrders({
  required List<Order> orders,
  required DateTime sourceBusinessDay,
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  final normalized = DateTime(
    sourceBusinessDay.year,
    sourceBusinessDay.month,
    sourceBusinessDay.day,
  );
  return orders.where((o) {
    if (o.orderType != OrderType.daily) return false;
    if (!_unresolvedStatuses.contains(o.status)) return false;
    final key = businessDayKey(o.orderDate, rolloverHour: rolloverHour);
    return DateTime(key.year, key.month, key.day) == normalized;
  }).toList();
}

bool isCustomerActiveForRecreation(
  Order source,
  List<Customer> customers,
) {
  final customer = customers.firstWhereOrNull(
    (c) => c.id == source.customerId,
  );
  if (customer == null) return false;
  return customer.isActive;
}

bool isActiveDailyOrderStatus(OrderStatus status) {
  return status != OrderStatus.cancelled;
}

bool isEligibleRecreationSource(
  Order order,
  DateTime sourceBusinessDay, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  if (order.orderType != OrderType.daily) return false;
  if (!isActiveDailyOrderStatus(order.status)) return false;
  if (order.items.isEmpty) return false;
  final key = businessDayKey(order.orderDate, rolloverHour: rolloverHour);
  final normalized = DateTime(key.year, key.month, key.day);
  final source = DateTime(
    sourceBusinessDay.year,
    sourceBusinessDay.month,
    sourceBusinessDay.day,
  );
  return normalized == source;
}

bool _orderOnBusinessDay(
  Order order,
  DateTime businessDay, {
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  final key = businessDayKey(order.orderDate, rolloverHour: rolloverHour);
  final normalized = DateTime(key.year, key.month, key.day);
  final target = DateTime(
    businessDay.year,
    businessDay.month,
    businessDay.day,
  );
  return normalized == target;
}

/// Locates the pending next-day order linked to [source] via [recreatedFromOrderId].
Order? findNextDayPendingOrder({
  required Order source,
  required List<Order> orders,
  required DateTime targetBusinessDay,
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  return orders.firstWhereOrNull(
    (o) =>
        o.recreatedFromOrderId == source.id &&
        o.status == OrderStatus.pending &&
        _orderOnBusinessDay(
          o,
          targetBusinessDay,
          rolloverHour: rolloverHour,
        ),
  );
}

/// True when this [source] already has a pending child on [targetBusinessDay].
bool hasPendingOrderForTargetDay({
  required Order source,
  required List<Order> orders,
  required DateTime targetBusinessDay,
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  return findNextDayPendingOrder(
        source: source,
        orders: orders,
        targetBusinessDay: targetBusinessDay,
        rolloverHour: rolloverHour,
      ) !=
      null;
}

/// Every auto-recreated order must start as pending with a clean payment state.
Order ensureRecreatedOrderIsPending(Order order) {
  return Order(
    id: order.id,
    factoryId: order.factoryId,
    orderType: order.orderType,
    deliveryRun: order.deliveryRun,
    customerId: order.customerId,
    customerName: order.customerName,
    customerEmail: order.customerEmail,
    customerPhone: order.customerPhone,
    customerAddress: order.customerAddress,
    items: order.items,
    subtotal: order.subtotal,
    discountAmount: order.discountAmount,
    totalAmount: order.totalAmount,
    paymentStatus: PaymentStatus.unpaid,
    paymentMethod: null,
    amountPaid: null,
    status: OrderStatus.pending,
    assignedRoute: order.assignedRoute,
    assignedDriver: order.assignedDriver,
    orderDate: order.orderDate,
    deliveryDate: null,
    paymentTime: null,
    deliveryTime: null,
    notes: order.notes,
    recreatedFromOrderId: order.recreatedFromOrderId,
    createdAt: order.createdAt,
    updatedAt: order.updatedAt,
  );
}

Order buildRecreatedOrder({
  required Order source,
  required DateTime targetBusinessDay,
  required String newId,
  int rolloverHour = kDefaultBusinessDayRolloverHour,
}) {
  final now = DateTime.now();
  final orderDate = orderDateForBusinessDay(
    targetBusinessDay,
    rolloverHour: rolloverHour,
  );
  return Order(
    id: newId,
    factoryId: source.factoryId,
    orderType: OrderType.daily,
    deliveryRun: source.deliveryRun,
    customerId: source.customerId,
    customerName: source.customerName,
    customerEmail: source.customerEmail,
    customerPhone: source.customerPhone,
    customerAddress: source.customerAddress,
    items: source.items,
    subtotal: source.subtotal,
    discountAmount: source.discountAmount,
    totalAmount: source.totalAmount,
    paymentStatus: PaymentStatus.unpaid,
    paymentMethod: null,
    amountPaid: null,
    status: OrderStatus.pending,
    assignedRoute: source.assignedRoute,
    assignedDriver: source.assignedDriver,
    orderDate: orderDate,
    deliveryDate: null,
    paymentTime: null,
    deliveryTime: null,
    notes: source.notes,
    recreatedFromOrderId: source.id,
    createdAt: now,
    updatedAt: now,
  );
}

Order buildSyncedNextDayOrder(Order existing, Order source) {
  final now = DateTime.now();
  return existing.copyWith(
    deliveryRun: source.deliveryRun,
    items: source.items,
    subtotal: source.subtotal,
    discountAmount: source.discountAmount,
    totalAmount: source.totalAmount,
    customerName: source.customerName,
    customerEmail: source.customerEmail,
    customerPhone: source.customerPhone,
    customerAddress: source.customerAddress,
    assignedRoute: source.assignedRoute,
    assignedDriver: source.assignedDriver,
    notes: source.notes,
    status: OrderStatus.pending,
    paymentStatus: PaymentStatus.unpaid,
    updatedAt: now,
  );
}

/// Layer A — sync only: update an existing pending next-day order from a daily source.
DailyOrderRecreationResult? syncNextDayFromSource({
  required Order source,
  required List<Order> orders,
  required List<Customer> customers,
  required int rolloverHour,
  required void Function(Order order) updateOrder,
}) {
  if (source.orderType != OrderType.daily) return null;

  if (source.status == OrderStatus.cancelled) {
    final linked = orders.where(
      (o) =>
          o.recreatedFromOrderId == source.id &&
          o.status == OrderStatus.pending,
    );
    var cancelled = 0;
    for (final pending in linked) {
      updateOrder(
        pending.copyWith(
          status: OrderStatus.cancelled,
          updatedAt: DateTime.now(),
        ),
      );
      cancelled++;
    }
    if (cancelled == 0) return null;
    return DailyOrderRecreationResult(cancelledCount: cancelled);
  }

  if (!isActiveDailyOrderStatus(source.status)) return null;
  if (source.items.isEmpty) return null;
  if (!isCustomerActiveForRecreation(source, customers)) return null;

  final sourceDay = businessDayKey(source.orderDate, rolloverHour: rolloverHour);
  final targetDay = DateTime(
    sourceDay.year,
    sourceDay.month,
    sourceDay.day,
  ).add(const Duration(days: 1));

  final existing = findNextDayPendingOrder(
    source: source,
    orders: orders,
    targetBusinessDay: targetDay,
    rolloverHour: rolloverHour,
  );
  if (existing == null || existing.status != OrderStatus.pending) return null;

  final synced = ensureRecreatedOrderIsPending(
    buildSyncedNextDayOrder(existing, source),
  );
  if (const DeepCollectionEquality().equals(
    _orderContentSnapshot(existing),
    _orderContentSnapshot(synced),
  )) {
    return null;
  }

  updateOrder(synced);
  return const DailyOrderRecreationResult(syncedCount: 1);
}

Map<String, dynamic> _orderContentSnapshot(Order order) {
  return {
    'deliveryRun': order.deliveryRun.name,
    'items': order.items.map((i) => i.toJson()).toList(),
    'subtotal': order.subtotal,
    'discountAmount': order.discountAmount,
    'totalAmount': order.totalAmount,
    'notes': order.notes,
    'assignedRoute': order.assignedRoute,
    'assignedDriver': order.assignedDriver,
  };
}

/// Layer B — create missing orders for one target business day.
Future<DailyOrderRecreationResult> runBatchForTargetDay({
  required DateTime targetBusinessDay,
  required List<Order> orders,
  required List<Customer> customers,
  required int rolloverHour,
  required FutureOr<void> Function(Order order) addOrder,
}) async {
  final sourceDay = DateTime(
    targetBusinessDay.year,
    targetBusinessDay.month,
    targetBusinessDay.day,
  ).subtract(const Duration(days: 1));

  final sources = orders.where(
    (o) => isEligibleRecreationSource(
      o,
      sourceDay,
      rolloverHour: rolloverHour,
    ),
  );

  final createdIds = <String>[];
  for (final source in sources) {
    if (!isCustomerActiveForRecreation(source, customers)) continue;
    if (hasPendingOrderForTargetDay(
      source: source,
      orders: orders,
      targetBusinessDay: targetBusinessDay,
      rolloverHour: rolloverHour,
    )) {
      continue;
    }

    const uuid = Uuid();
    final created = ensureRecreatedOrderIsPending(
      buildRecreatedOrder(
        source: source,
        targetBusinessDay: targetBusinessDay,
        newId: uuid.v4(),
        rolloverHour: rolloverHour,
      ),
    );
    await addOrder(created);
    createdIds.add(created.id);
    orders = [...orders, created];
  }

  return DailyOrderRecreationResult(
    createdCount: createdIds.length,
    createdOrderIds: createdIds,
  );
}

/// Layer B — multi-day catch-up from last run through today (when rollover passed).
Future<DailyOrderRecreationResult> runRolloverBatch({
  required String factoryId,
  required List<Order> orders,
  required List<Customer> customers,
  required int rolloverHour,
  required DateTime now,
  required FutureOr<void> Function(Order order) addOrder,
  bool autoRecreationEnabled = true,
}) async {
  if (!autoRecreationEnabled) {
    return const DailyOrderRecreationResult();
  }
  if (!hasPassedBusinessDayRollover(now, rolloverHour: rolloverHour)) {
    return const DailyOrderRecreationResult();
  }

  final currentKey = currentBusinessDayKey(
    reference: now,
    rolloverHour: rolloverHour,
  );
  final normalizedCurrent = DateTime(
    currentKey.year,
    currentKey.month,
    currentKey.day,
  );

  final lastRun = await DailyOrderRecreationPrefs.loadLastRunDay(factoryId);
  final normalizedLast = lastRun == null
      ? normalizedCurrent.subtract(const Duration(days: 1))
      : DateTime(lastRun.year, lastRun.month, lastRun.day);

  if (!normalizedLast.isBefore(normalizedCurrent)) {
    return const DailyOrderRecreationResult();
  }

  var day = normalizedLast.add(const Duration(days: 1));
  var result = const DailyOrderRecreationResult();
  var daysProcessed = 0;
  final mutableOrders = [...orders];

  while (!day.isAfter(normalizedCurrent) && daysProcessed < kMaxBackfillBusinessDays) {
    final dayResult = await runBatchForTargetDay(
      targetBusinessDay: day,
      orders: mutableOrders,
      customers: customers,
      rolloverHour: rolloverHour,
      addOrder: (order) async {
        await addOrder(order);
        mutableOrders.add(order);
      },
    );
    result = result.merge(dayResult);
    day = day.add(const Duration(days: 1));
    daysProcessed++;
  }

  await DailyOrderRecreationPrefs.saveLastRunDay(factoryId, normalizedCurrent);
  return result;
}
