import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' hide Factory;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_controller.dart';
import 'app_startup.dart';
import '../data/models/order.dart';
import '../data/models/customer.dart';
import '../data/models/food_item.dart';
import '../data/models/delivery_route.dart';
import '../data/models/driver.dart';
import '../data/models/factory.dart';
import '../core/orders/business_day.dart';
import '../core/orders/daily_order_recreation_service.dart';
import '../core/services/firebase_service.dart';
import '../core/services/factory_service.dart';
import '../core/services/local_notifications_service.dart';
import '../core/services/route_ref_migration.dart';
import '../core/utils/route_refs.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Data is passed in (not read from providers here) so this can be called from
// any notifier's `ref` without tripping Riverpod's "a provider cannot depend on
// itself" assertion when the caller reads its own provider.
void _scheduleRouteRefMigration(
  String factoryId, {
  required List<DeliveryRoute> routes,
  required List<Customer> customers,
  required List<Order> orders,
}) {
  Future.microtask(() async {
    if (routes.isEmpty) return;
    await RouteRefMigration.syncIfNeeded(
      factoryId: factoryId,
      routes: routes,
      customers: customers,
      orders: orders,
    );
  });
}

CollectionReference<Map<String, dynamic>> _mapCollection(String path) {
  return FirebaseService.firestore
      .collection(path)
      .withConverter<Map<String, dynamic>>(
        fromFirestore: (snapshot, _) => snapshot.data() ?? <String, dynamic>{},
        toFirestore: (data, _) => data,
      );
}

final appStartupProvider =
    NotifierProvider<AppStartupNotifier, AppStartupState>(
      AppStartupNotifier.new,
    );

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

final factoryIdProvider = FutureProvider<String?>((ref) async {
  final authState = ref.watch(authProvider);
  if (authState.user == null) return null;

  try {
    return await FactoryService.resolveFactoryId(
      providedFactoryId: authState.user?.factoryId,
      user: authState.user,
    );
  } catch (e) {
    debugPrint('[FactoryIdProvider] Error: $e');
    return authState.user?.factoryId;
  }
});

/// Loads the current user's factory/company record. Tolerant of partially
/// written factory docs (onboarding may only set `name`), so it constructs a
/// [Factory] with safe defaults rather than using the strict `fromJson`.
final factoryProvider = FutureProvider<Factory?>((ref) async {
  final factoryId = await ref.watch(factoryIdProvider.future);
  if (factoryId == null || factoryId.isEmpty) return null;
  if (!FirebaseService.isInitialized) return null;

  try {
    final doc = await FirebaseService.firestore
        .collection('factories')
        .doc(factoryId)
        .get();
    if (!doc.exists) return null;

    final data = doc.data() ?? const <String, dynamic>{};
    final name = (data['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) return null;

    final now = DateTime.now();
    return Factory(
      id: factoryId,
      name: name,
      address: (data['address'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim(),
      createdAt: now,
      updatedAt: now,
    );
  } catch (e) {
    debugPrint('[FactoryProvider] Error: $e');
    return null;
  }
});

// Domain States (Global for both Owner and Delivery roles)

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);

final customersProvider = NotifierProvider<CustomersNotifier, List<Customer>>(
  CustomersNotifier.new,
);

final foodItemsProvider = NotifierProvider<FoodItemsNotifier, List<FoodItem>>(
  FoodItemsNotifier.new,
);

final routesProvider = NotifierProvider<RoutesNotifier, List<DeliveryRoute>>(
  RoutesNotifier.new,
);

final driversProvider = NotifierProvider<DriversNotifier, List<Driver>>(
  DriversNotifier.new,
);

class LastTouchedOrderState {
  final String id;
  final bool wasCreated;
  final DateTime at;

  const LastTouchedOrderState({
    required this.id,
    required this.wasCreated,
    required this.at,
  });
}

final lastTouchedOrderProvider =
    NotifierProvider<LastTouchedOrderNotifier, LastTouchedOrderState?>(
      LastTouchedOrderNotifier.new,
    );

class LastTouchedOrderNotifier extends Notifier<LastTouchedOrderState?> {
  @override
  LastTouchedOrderState? build() => null;

  void set({required String id, required bool wasCreated}) {
    state = LastTouchedOrderState(
      id: id,
      wasCreated: wasCreated,
      at: DateTime.now(),
    );
  }

  void clear() => state = null;
}

final ordersLoadedProvider = NotifierProvider<_LoadedFlagNotifier, bool>(
  _LoadedFlagNotifier.new,
);
final customersLoadedProvider = NotifierProvider<_LoadedFlagNotifier, bool>(
  _LoadedFlagNotifier.new,
);
final foodItemsLoadedProvider = NotifierProvider<_LoadedFlagNotifier, bool>(
  _LoadedFlagNotifier.new,
);
final routesLoadedProvider = NotifierProvider<_LoadedFlagNotifier, bool>(
  _LoadedFlagNotifier.new,
);
final driversLoadedProvider = NotifierProvider<_LoadedFlagNotifier, bool>(
  _LoadedFlagNotifier.new,
);

/// True when the Orders screen's current filtered view is showing an empty
/// state. The shell watches this to hide the "+" FAB (the empty state has its
/// own actions, so the floating button would be redundant).
final ordersViewIsEmptyProvider =
    NotifierProvider<OrdersViewEmptyNotifier, bool>(
      OrdersViewEmptyNotifier.new,
    );

class OrdersViewEmptyNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

// Notifiers for domain states

class _LoadedFlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

String _humanizeStatus(OrderStatus status) {
  final name = status.name;
  if (name.isEmpty) return name;
  return name[0].toUpperCase() + name.substring(1);
}

String _formatOrderShortId(String id) {
  final trimmed = id.trim();
  if (trimmed.isEmpty) return '#ORD';
  final upper = trimmed.toUpperCase();
  if (upper.startsWith('ORD-') || upper.startsWith('#ORD-')) {
    return upper.startsWith('#') ? upper : '#$upper';
  }
  final short = upper.length > 6 ? upper.substring(0, 6) : upper;
  return '#$short';
}

String _formatOrderAlertBody(Order order, {required String suffix}) {
  final id = _formatOrderShortId(order.id);
  final name = order.customerName.trim();
  if (name.isEmpty) return '$id $suffix';
  return '$id · $name $suffix';
}

class OrdersNotifier extends Notifier<List<Order>> {
  StreamSubscription? _subscription;
  String? _activeFactoryId;
  bool _isListening = false;

  /// Tracks the last seen status for each order so we can diff against the
  /// next Firestore snapshot and fire notifications only on real changes.
  Map<String, OrderStatus> _prevStatusById = {};
  bool _firstSnapshotProcessed = false;

  /// Order ids that were just mutated locally by this device. We suppress
  /// notifications for these so users don't get pinged for their own taps.
  /// Each entry expires after [_selfMutationTtl].
  final Map<String, DateTime> _selfMutationsAt = {};
  static const Duration _selfMutationTtl = Duration(seconds: 12);

  bool _recreationCatchUpScheduled = false;
  bool _recreationCatchUpRunning = false;

  void _markSelfMutation(String orderId) {
    _selfMutationsAt[orderId] = DateTime.now();
  }

  bool _isFreshSelfMutation(String orderId) {
    final at = _selfMutationsAt[orderId];
    if (at == null) return false;
    if (DateTime.now().difference(at) > _selfMutationTtl) {
      _selfMutationsAt.remove(orderId);
      return false;
    }
    return true;
  }

  @override
  List<Order> build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      _isListening = false;
      _prevStatusById = {};
      _firstSnapshotProcessed = false;
      _selfMutationsAt.clear();
    });

    if (!_isListening) {
      _isListening = true;
      ref.listen<AsyncValue<String?>>(
        factoryIdProvider,
        (_, next) => Future.microtask(() => _setFactoryId(next.asData?.value)),
        fireImmediately: true,
      );
      // Daily recreation catch-up bails out when customers aren't loaded yet
      // (see runDailyRecreationCatchUp). On a cold start the orders snapshot
      // can arrive before customers finish loading, so the catch-up scheduled
      // from that snapshot does nothing and today's daily orders are never
      // created until a manual refresh. Re-schedule it the moment customers
      // become available so generation happens automatically.
      ref.listen<bool>(customersLoadedProvider, (prev, next) {
        if (next && prev != true) {
          final factoryId = _activeFactoryId;
          if (factoryId != null) {
            _scheduleDailyRecreationCatchUp(factoryId);
          }
        }
      });
    }

    return [];
  }

  void _setFactoryId(String? factoryId) {
    if (factoryId == null) {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      _prevStatusById = {};
      _firstSnapshotProcessed = false;
      state = [];
      Future.microtask(() {
        ref.read(ordersLoadedProvider.notifier).state = false;
      });
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;
    _prevStatusById = {};
    _firstSnapshotProcessed = false;
    Future.microtask(() {
      ref.read(ordersLoadedProvider.notifier).state = false;
    });

    try {
      _subscription = _mapCollection('orders')
          .where('factoryId', isEqualTo: factoryId)
          .snapshots()
          .listen(
            (snapshot) {
              final customers = ref.read(customersProvider);
              final routes = ref.read(routesProvider);

              String? deriveRouteKey(Order o) {
                final raw = o.assignedRoute?.trim();
                if (raw != null && raw.isNotEmpty) return raw;

                final byId = customers.firstWhereOrNull(
                  (c) => c.id == o.customerId,
                );
                final idRoute = byId?.assignedRoute?.trim();
                if (idRoute?.isNotEmpty == true) return idRoute;

                final phone = o.customerPhone.trim();
                if (phone.isNotEmpty) {
                  final byPhone = customers.firstWhereOrNull(
                    (c) => c.phone.trim() == phone,
                  );
                  final phoneRoute = byPhone?.assignedRoute?.trim();
                  if (phoneRoute?.isNotEmpty == true) return phoneRoute;
                }

                final name = o.customerName.trim().toLowerCase();
                if (name.isNotEmpty) {
                  final byName = customers.firstWhereOrNull(
                    (c) => c.name.trim().toLowerCase() == name,
                  );
                  final nameRoute = byName?.assignedRoute?.trim();
                  if (nameRoute?.isNotEmpty == true) return nameRoute;
                }
                return null;
              }

              String? normalizeRouteId(String? key) {
                final resolved = RouteRefs.routeIdForRef(key, routes);
                if (resolved != null) return resolved;
                final k = key?.trim();
                if (k == null || k.isEmpty) return null;
                return k;
              }

              String? normalizeDriverId(String? routeId) {
                if (routeId == null) return null;
                final r = routes.firstWhereOrNull((r) => r.id == routeId);
                final d = r?.assignedDriver?.trim();
                if (d == null || d.isEmpty) return null;
                return d;
              }

              final nextOrders = <Order>[];
              for (final doc in snapshot.docs) {
                try {
                  final data = doc.data();
                  final fid = (data['factoryId'] ?? data['factory_id'])
                      ?.toString();
                  if (fid != factoryId) continue;
                  final o = Order.fromJson({...data, 'id': doc.id});
                  final derivedKey = deriveRouteKey(o);
                  final normalizedId = normalizeRouteId(derivedKey);
                  final normalizedDriver = normalizeDriverId(normalizedId);

                  final routeSame =
                      (o.assignedRoute?.trim().isNotEmpty == true
                          ? o.assignedRoute!.trim()
                          : null) ==
                      normalizedId;
                  final driverSame =
                      (o.assignedDriver?.trim().isNotEmpty == true
                          ? o.assignedDriver!.trim()
                          : null) ==
                      normalizedDriver;

                  nextOrders.add(
                    routeSame && driverSame
                        ? o
                        : o.copyWith(
                            assignedRoute: normalizedId,
                            assignedDriver: normalizedDriver,
                          ),
                  );
                } catch (e) {
                  debugPrint(
                    '[Firestore] Skipping bad order doc ${doc.id}: $e',
                  );
                }
              }

              _emitOrderNotifications(nextOrders);

              state = nextOrders;
              _scheduleRouteRefMigration(
                factoryId,
                routes: ref.read(routesProvider),
                customers: ref.read(customersProvider),
                orders: state,
              );
              _scheduleDailyRecreationCatchUp(factoryId);
              Future.microtask(() {
                ref.read(ordersLoadedProvider.notifier).state = true;
              });
            },
            onError: (Object e, StackTrace st) {
              debugPrint('[Firestore] Error fetching orders: $e');
              Future.microtask(() {
                ref.read(ordersLoadedProvider.notifier).state = true;
              });
            },
          );
    } catch (e) {
      debugPrint('[Firestore] Error fetching orders: $e');
      Future.microtask(() {
        ref.read(ordersLoadedProvider.notifier).state = true;
      });
    }
  }

  Future<void> addOrder(Order order) async {
    final toSave = order.recreatedFromOrderId != null
        ? ensureRecreatedOrderIsPending(order)
        : order;
    _markSelfMutation(toSave.id);
    try {
      await FirebaseService.firestore
          .collection('orders')
          .doc(toSave.id)
          .set(toSave.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] addOrder error: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateOrder(Order order) async {
    final previous = state.firstWhereOrNull((o) => o.id == order.id);
    _markSelfMutation(order.id);
    try {
      await FirebaseService.firestore
          .collection('orders')
          .doc(order.id)
          .set(order.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] updateOrder error: $e\n$st');
      rethrow;
    }
    _handleDailyRecreationAfterUpdate(previous, order);
  }

  Future<int> _readRolloverHour(String factoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt('factory_${factoryId}_orderRolloverHour');
    if (stored != null && stored >= 0 && stored <= 23) return stored;
    return kDefaultBusinessDayRolloverHour;
  }

  void _handleDailyRecreationAfterUpdate(Order? previous, Order updated) {
    final factoryId = _activeFactoryId;
    if (factoryId == null) return;

    Future.microtask(() async {
      final enabled = await DailyOrderRecreationPrefs.isAutoRecreateEnabled(
        factoryId,
      );
      if (!enabled) return;

      final rolloverHour = await _readRolloverHour(factoryId);
      final customers = ref.read(customersProvider);
      final orders = state;

      Order? syncedTarget;
      final result = syncNextDayFromSource(
        source: updated,
        orders: orders,
        customers: customers,
        rolloverHour: rolloverHour,
        updateOrder: (synced) async {
          syncedTarget = synced;
          _markSelfMutation(synced.id);
          try {
            await FirebaseService.firestore
                .collection('orders')
                .doc(synced.id)
                .set(synced.toJson());
          } catch (e, st) {
            debugPrint('[Firestore] sync next-day order error: $e\n$st');
          }
        },
      );

      if (result != null && result.syncedCount > 0 && syncedTarget != null) {
        ref
            .read(lastTouchedOrderProvider.notifier)
            .set(id: syncedTarget!.id, wasCreated: false);
      }

      if (updated.orderType == OrderType.daily &&
          isActiveDailyOrderStatus(updated.status)) {
        _scheduleDailyRecreationCatchUp(factoryId);
      }
    });
  }

  void _scheduleDailyRecreationCatchUp(String factoryId) {
    if (_recreationCatchUpScheduled || _recreationCatchUpRunning) return;
    _recreationCatchUpScheduled = true;
    Future.microtask(() async {
      _recreationCatchUpScheduled = false;
      await runDailyRecreationCatchUp(factoryId);
    });
  }

  Future<DailyOrderRecreationResult> runDailyRecreationCatchUp(
    String factoryId,
  ) async {
    if (_recreationCatchUpRunning) {
      return const DailyOrderRecreationResult();
    }
    _recreationCatchUpRunning = true;
    try {
      final enabled = await DailyOrderRecreationPrefs.isAutoRecreateEnabled(
        factoryId,
      );
      if (!enabled) return const DailyOrderRecreationResult();
      if (!ref.read(customersLoadedProvider)) {
        return const DailyOrderRecreationResult();
      }

      final rolloverHour = await _readRolloverHour(factoryId);
      final customers = ref.read(customersProvider);
      final orders = state;

      // Auto-recreation runs silently: today's orders are created from
      // yesterday's active daily orders without gating on unresolved ones,
      // so the owner is never blocked by an interruptive review popup.
      final result = await runRolloverBatch(
        factoryId: factoryId,
        orders: orders,
        customers: customers,
        rolloverHour: rolloverHour,
        now: DateTime.now(),
        addOrder: addOrder,
        autoRecreationEnabled: enabled,
        allowUnresolvedSources: true,
      );

      for (final id in result.createdOrderIds) {
        ref
            .read(lastTouchedOrderProvider.notifier)
            .set(id: id, wasCreated: true);
      }

      return result;
    } finally {
      _recreationCatchUpRunning = false;
    }
  }

  /// Manual trigger from Settings — fills every missing daily-order day from
  /// the last day that has orders up to today, without waiting for the rollover.
  /// Bridges multi-day gaps (e.g. recreation was broken for a stretch) and
  /// never duplicates days that already have orders.
  Future<DailyOrderRecreationResult> runManualDailyOrderGeneration(
    String factoryId,
  ) async {
    final rolloverHour = await _readRolloverHour(factoryId);
    final customers = ref.read(customersProvider);
    final now = DateTime.now();

    final result = await runGapBackfill(
      throughDay: now,
      orders: state,
      customers: customers,
      rolloverHour: rolloverHour,
      addOrder: addOrder,
    );

    for (final id in result.createdOrderIds) {
      ref.read(lastTouchedOrderProvider.notifier).set(id: id, wasCreated: true);
    }

    return result;
  }

  /// Generate one specific day's daily orders (e.g. the owner picks a future
  /// day and taps Generate). Sources from the most recent earlier day that has
  /// orders and dedups, so re-running never duplicates.
  Future<DailyOrderRecreationResult> runDailyGenerationForDay(
    String factoryId,
    DateTime targetDay,
  ) async {
    final rolloverHour = await _readRolloverHour(factoryId);
    final customers = ref.read(customersProvider);
    final target = DateTime(targetDay.year, targetDay.month, targetDay.day);

    final sourceDay = latestDayWithDailySources(
      orders: state,
      before: target,
      rolloverHour: rolloverHour,
    );

    final result = await runBatchForTargetDay(
      targetBusinessDay: target,
      sourceBusinessDay: sourceDay,
      orders: state,
      customers: customers,
      rolloverHour: rolloverHour,
      addOrder: addOrder,
    );

    for (final id in result.createdOrderIds) {
      ref.read(lastTouchedOrderProvider.notifier).set(id: id, wasCreated: true);
    }

    return result;
  }

  Future<void> deleteOrder(String id) async {
    _markSelfMutation(id);
    try {
      await FirebaseService.firestore.collection('orders').doc(id).delete();
    } catch (e, st) {
      debugPrint('[Firestore] deleteOrder error: $e\n$st');
      rethrow;
    }
  }

  void _emitOrderNotifications(List<Order> nextOrders) {
    final nextById = <String, OrderStatus>{
      for (final o in nextOrders) o.id: o.status,
    };

    // Skip notifications during the initial snapshot — every order would
    // otherwise appear "new" right after sign in / app launch.
    if (!_firstSnapshotProcessed) {
      _prevStatusById = nextById;
      _firstSnapshotProcessed = true;
      return;
    }

    final notifier = LocalNotificationsService.instance;
    for (final order in nextOrders) {
      if (_isFreshSelfMutation(order.id)) continue;

      final prev = _prevStatusById[order.id];
      if (prev == null) {
        notifier.showOrderAlert(
          title: 'New order received',
          body: _formatOrderAlertBody(order, suffix: 'placed'),
          payload: 'order:${order.id}',
        );
      } else if (prev != order.status) {
        notifier.showOrderAlert(
          title: 'Order status updated',
          body: _formatOrderAlertBody(
            order,
            suffix: 'is now ${_humanizeStatus(order.status)}',
          ),
          payload: 'order:${order.id}',
        );
      }
    }

    _prevStatusById = nextById;
  }

  Future<void> refresh() async {
    final id = _activeFactoryId;
    if (id == null) return;
    _subscription?.cancel();
    _subscription = null;
    _setFactoryId(id);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }
}

class CustomersNotifier extends Notifier<List<Customer>> {
  StreamSubscription? _subscription;
  String? _activeFactoryId;
  bool _isListening = false;

  @override
  List<Customer> build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      _isListening = false;
    });

    if (!_isListening) {
      _isListening = true;
      ref.listen<AsyncValue<String?>>(
        factoryIdProvider,
        (_, next) => Future.microtask(() => _setFactoryId(next.asData?.value)),
        fireImmediately: true,
      );
    }

    return [];
  }

  void _setFactoryId(String? factoryId) {
    if (factoryId == null) {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      state = [];
      Future.microtask(() {
        ref.read(customersLoadedProvider.notifier).state = false;
      });
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;
    Future.microtask(() {
      ref.read(customersLoadedProvider.notifier).state = false;
    });

    try {
      _subscription = _mapCollection('customers')
          .where('factoryId', isEqualTo: factoryId)
          .snapshots()
          .listen(
            (snapshot) {
              final parsed = <Customer>[];
              for (final doc in snapshot.docs) {
                try {
                  parsed.add(Customer.fromJson({...doc.data(), 'id': doc.id}));
                } catch (e) {
                  debugPrint(
                    '[Firestore] Skipping bad customer doc ${doc.id}: $e',
                  );
                }
              }
              state = parsed;
              _scheduleRouteRefMigration(
                factoryId,
                routes: ref.read(routesProvider),
                customers: state,
                orders: ref.read(ordersProvider),
              );
              Future.microtask(() {
                ref.read(customersLoadedProvider.notifier).state = true;
              });
            },
            onError: (Object e, StackTrace st) {
              debugPrint('[Firestore] Error fetching customers: $e');
              Future.microtask(() {
                ref.read(customersLoadedProvider.notifier).state = true;
              });
            },
          );
    } catch (e) {
      debugPrint('[Firestore] Error fetching customers: $e');
      Future.microtask(() {
        ref.read(customersLoadedProvider.notifier).state = true;
      });
    }
  }

  Future<void> addCustomer(Customer customer) async {
    try {
      await FirebaseService.firestore
          .collection('customers')
          .doc(customer.id)
          .set(customer.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] addCustomer error: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateCustomer(Customer customer) async {
    try {
      await FirebaseService.firestore
          .collection('customers')
          .doc(customer.id)
          .set(customer.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] updateCustomer error: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteCustomer(String id) async {
    try {
      await FirebaseService.firestore.collection('customers').doc(id).delete();
    } catch (e, st) {
      debugPrint('[Firestore] deleteCustomer error: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    final id = _activeFactoryId;
    if (id == null) return;
    _subscription?.cancel();
    _subscription = null;
    _setFactoryId(id);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }
}

class FoodItemsNotifier extends Notifier<List<FoodItem>> {
  StreamSubscription? _subscription;
  String? _activeFactoryId;
  bool _isListening = false;

  @override
  List<FoodItem> build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      _isListening = false;
    });

    if (!_isListening) {
      _isListening = true;
      ref.listen<AsyncValue<String?>>(
        factoryIdProvider,
        (_, next) => Future.microtask(() => _setFactoryId(next.asData?.value)),
        fireImmediately: true,
      );
    }

    return [];
  }

  void _setFactoryId(String? factoryId) {
    if (factoryId == null) {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      state = [];
      Future.microtask(() {
        ref.read(foodItemsLoadedProvider.notifier).state = false;
      });
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;
    Future.microtask(() {
      ref.read(foodItemsLoadedProvider.notifier).state = false;
    });

    try {
      _subscription = _mapCollection('foodItems')
          .where('factoryId', isEqualTo: factoryId)
          .snapshots()
          .listen(
            (snapshot) {
              final parsed = <FoodItem>[];
              for (final doc in snapshot.docs) {
                try {
                  parsed.add(FoodItem.fromJson({...doc.data(), 'id': doc.id}));
                } catch (e) {
                  debugPrint(
                    '[Firestore] Skipping bad foodItem doc ${doc.id}: $e',
                  );
                }
              }
              state = parsed;
              Future.microtask(() {
                ref.read(foodItemsLoadedProvider.notifier).state = true;
              });
            },
            onError: (Object e, StackTrace st) {
              debugPrint('[Firestore] Error fetching food items: $e');
              Future.microtask(() {
                ref.read(foodItemsLoadedProvider.notifier).state = true;
              });
            },
          );
    } catch (e) {
      debugPrint('[Firestore] Error fetching food items: $e');
      Future.microtask(() {
        ref.read(foodItemsLoadedProvider.notifier).state = true;
      });
    }
  }

  Future<void> addFoodItem(FoodItem item) async {
    try {
      await FirebaseService.firestore
          .collection('foodItems')
          .doc(item.id)
          .set(item.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] addFoodItem error: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateFoodItem(FoodItem item) async {
    try {
      await FirebaseService.firestore
          .collection('foodItems')
          .doc(item.id)
          .set(item.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] updateFoodItem error: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteFoodItem(String id) async {
    try {
      await FirebaseService.firestore.collection('foodItems').doc(id).delete();
    } catch (e, st) {
      debugPrint('[Firestore] deleteFoodItem error: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    final id = _activeFactoryId;
    if (id == null) return;
    _subscription?.cancel();
    _subscription = null;
    _setFactoryId(id);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }
}

class RoutesNotifier extends Notifier<List<DeliveryRoute>> {
  StreamSubscription? _subscription;
  String? _activeFactoryId;
  bool _isListening = false;

  @override
  List<DeliveryRoute> build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      _isListening = false;
    });

    if (!_isListening) {
      _isListening = true;
      ref.listen<AsyncValue<String?>>(
        factoryIdProvider,
        (_, next) => Future.microtask(() => _setFactoryId(next.asData?.value)),
        fireImmediately: true,
      );
    }

    return [];
  }

  void _setFactoryId(String? factoryId) {
    if (factoryId == null) {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      state = [];
      Future.microtask(() {
        ref.read(routesLoadedProvider.notifier).state = false;
      });
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;
    Future.microtask(() {
      ref.read(routesLoadedProvider.notifier).state = false;
    });

    try {
      _subscription = _mapCollection('routes')
          .where('factoryId', isEqualTo: factoryId)
          .snapshots()
          .listen(
            (snapshot) {
              final parsed = <DeliveryRoute>[];
              for (final doc in snapshot.docs) {
                try {
                  parsed.add(
                    DeliveryRoute.fromJson({...doc.data(), 'id': doc.id}),
                  );
                } catch (e) {
                  debugPrint(
                    '[Firestore] Skipping bad route doc ${doc.id}: $e',
                  );
                }
              }
              state = parsed;
              _scheduleRouteRefMigration(
                factoryId,
                routes: state,
                customers: ref.read(customersProvider),
                orders: ref.read(ordersProvider),
              );
              Future.microtask(() {
                ref.read(routesLoadedProvider.notifier).state = true;
              });
            },
            onError: (Object e, StackTrace st) {
              debugPrint('[Firestore] Error fetching routes: $e');
              Future.microtask(() {
                ref.read(routesLoadedProvider.notifier).state = true;
              });
            },
          );
    } catch (e) {
      debugPrint('[Firestore] Error fetching routes: $e');
      Future.microtask(() {
        ref.read(routesLoadedProvider.notifier).state = true;
      });
    }
  }

  Future<void> addRoute(DeliveryRoute route) async {
    try {
      await FirebaseService.firestore
          .collection('routes')
          .doc(route.id)
          .set(route.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] addRoute error: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateRoute(DeliveryRoute route) async {
    try {
      await FirebaseService.firestore
          .collection('routes')
          .doc(route.id)
          .set(route.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] updateRoute error: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteRoute(String id) async {
    try {
      await FirebaseService.firestore.collection('routes').doc(id).delete();
    } catch (e, st) {
      debugPrint('[Firestore] deleteRoute error: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    final id = _activeFactoryId;
    if (id == null) return;
    _subscription?.cancel();
    _subscription = null;
    _setFactoryId(id);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }
}

class DriversNotifier extends Notifier<List<Driver>> {
  StreamSubscription? _subscription;
  String? _activeFactoryId;
  bool _isListening = false;

  @override
  List<Driver> build() {
    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      _isListening = false;
    });

    if (!_isListening) {
      _isListening = true;
      ref.listen<AsyncValue<String?>>(
        factoryIdProvider,
        (_, next) => Future.microtask(() => _setFactoryId(next.asData?.value)),
        fireImmediately: true,
      );
    }

    return [];
  }

  void _setFactoryId(String? factoryId) {
    if (factoryId == null) {
      _subscription?.cancel();
      _subscription = null;
      _activeFactoryId = null;
      state = [];
      Future.microtask(() {
        ref.read(driversLoadedProvider.notifier).state = false;
      });
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;
    Future.microtask(() {
      ref.read(driversLoadedProvider.notifier).state = false;
    });

    try {
      _subscription = _mapCollection('drivers')
          .where('factoryId', isEqualTo: factoryId)
          .snapshots()
          .listen(
            (snapshot) {
              final parsed = <Driver>[];
              for (final doc in snapshot.docs) {
                try {
                  parsed.add(Driver.fromJson({...doc.data(), 'id': doc.id}));
                } catch (e) {
                  debugPrint(
                    '[Firestore] Skipping bad driver doc ${doc.id}: $e',
                  );
                }
              }
              state = parsed;
              Future.microtask(() {
                ref.read(driversLoadedProvider.notifier).state = true;
              });
            },
            onError: (Object e, StackTrace st) {
              debugPrint('[Firestore] Error fetching drivers: $e');
              Future.microtask(() {
                ref.read(driversLoadedProvider.notifier).state = true;
              });
            },
          );
    } catch (e) {
      debugPrint('[Firestore] Error fetching drivers: $e');
      Future.microtask(() {
        ref.read(driversLoadedProvider.notifier).state = true;
      });
    }
  }

  Future<void> addDriver(Driver driver) async {
    try {
      await FirebaseService.firestore
          .collection('drivers')
          .doc(driver.id)
          .set(driver.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] addDriver error: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateDriver(Driver driver) async {
    try {
      await FirebaseService.firestore
          .collection('drivers')
          .doc(driver.id)
          .set(driver.toJson());
    } catch (e, st) {
      debugPrint('[Firestore] updateDriver error: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteDriver(String id) async {
    try {
      await FirebaseService.firestore.collection('drivers').doc(id).delete();
    } catch (e, st) {
      debugPrint('[Firestore] deleteDriver error: $e\n$st');
      rethrow;
    }
  }

  Future<void> refresh() async {
    final id = _activeFactoryId;
    if (id == null) return;
    _subscription?.cancel();
    _subscription = null;
    _setFactoryId(id);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }
}
