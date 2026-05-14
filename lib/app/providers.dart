import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/auth_controller.dart';
import 'app_startup.dart';
import '../data/models/order.dart';
import '../data/models/customer.dart';
import '../data/models/food_item.dart';
import '../data/models/delivery_route.dart';
import '../data/models/driver.dart';
import '../core/services/firebase_service.dart';
import '../core/services/factory_service.dart';
import '../core/services/local_notifications_service.dart';

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
    return authState.user?.factoryId ?? 'FAC_00001'; // Fallback
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
  static const Duration _selfMutationTtl = Duration(seconds: 4);

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
      _subscription = _mapCollection('orders').snapshots().listen(
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
            if (key == null) return null;
            final k = key.trim();
            if (k.isEmpty) return null;
            final route = routes.firstWhereOrNull(
              (r) => r.id == k || r.name == k,
            );
            return route == null ? k : route.id;
          }

          String? normalizeDriverId(String? routeId) {
            if (routeId == null) return null;
            final r = routes.firstWhereOrNull((r) => r.id == routeId);
            final d = r?.assignedDriver?.trim();
            if (d == null || d.isEmpty) return null;
            return d;
          }

          final nextOrders = snapshot.docs
              .where((doc) {
                final data = doc.data();
                final fid = (data['factoryId'] ?? data['factory_id'])
                    ?.toString();
                return fid == factoryId;
              })
              .map((doc) {
                final o = Order.fromJson({...doc.data(), 'id': doc.id});
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

                if (routeSame && driverSame) return o;
                return o.copyWith(
                  assignedRoute: normalizedId,
                  assignedDriver: normalizedDriver,
                );
              })
              .toList();

          _emitOrderNotifications(nextOrders);

          state = nextOrders;
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

  void addOrder(Order order) {
    _markSelfMutation(order.id);
    FirebaseService.firestore
        .collection('orders')
        .doc(order.id)
        .set(order.toJson());
  }

  void updateOrder(Order order) {
    _markSelfMutation(order.id);
    FirebaseService.firestore
        .collection('orders')
        .doc(order.id)
        .set(order.toJson());
  }

  void deleteOrder(String id) {
    _markSelfMutation(id);
    FirebaseService.firestore.collection('orders').doc(id).delete();
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
              state = snapshot.docs
                  .map(
                    (doc) => Customer.fromJson({...doc.data(), 'id': doc.id}),
                  )
                  .toList();
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

  void addCustomer(Customer customer) => FirebaseService.firestore
      .collection('customers')
      .doc(customer.id)
      .set(customer.toJson());
  void updateCustomer(Customer customer) => FirebaseService.firestore
      .collection('customers')
      .doc(customer.id)
      .set(customer.toJson());
  Future<void> deleteCustomer(String id) =>
      FirebaseService.firestore.collection('customers').doc(id).delete();

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
              state = snapshot.docs
                  .map(
                    (doc) => FoodItem.fromJson({...doc.data(), 'id': doc.id}),
                  )
                  .toList();
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

  void addFoodItem(FoodItem item) => FirebaseService.firestore
      .collection('foodItems')
      .doc(item.id)
      .set(item.toJson());
  void updateFoodItem(FoodItem item) => FirebaseService.firestore
      .collection('foodItems')
      .doc(item.id)
      .set(item.toJson());
  void deleteFoodItem(String id) =>
      FirebaseService.firestore.collection('foodItems').doc(id).delete();

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
              state = snapshot.docs
                  .map(
                    (doc) =>
                        DeliveryRoute.fromJson({...doc.data(), 'id': doc.id}),
                  )
                  .toList();
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

  void addRoute(DeliveryRoute route) => FirebaseService.firestore
      .collection('routes')
      .doc(route.id)
      .set(route.toJson());
  void updateRoute(DeliveryRoute route) => FirebaseService.firestore
      .collection('routes')
      .doc(route.id)
      .set(route.toJson());
  void deleteRoute(String id) =>
      FirebaseService.firestore.collection('routes').doc(id).delete();

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
              state = snapshot.docs
                  .map((doc) => Driver.fromJson({...doc.data(), 'id': doc.id}))
                  .toList();
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

  void addDriver(Driver driver) => FirebaseService.firestore
      .collection('drivers')
      .doc(driver.id)
      .set(driver.toJson());
  void updateDriver(Driver driver) => FirebaseService.firestore
      .collection('drivers')
      .doc(driver.id)
      .set(driver.toJson());
  void deleteDriver(String id) =>
      FirebaseService.firestore.collection('drivers').doc(id).delete();

  Future<void> refresh() async {
    final id = _activeFactoryId;
    if (id == null) return;
    _subscription?.cancel();
    _subscription = null;
    _setFactoryId(id);
    await Future<void>.delayed(const Duration(milliseconds: 350));
  }
}
