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

class OrdersNotifier extends Notifier<List<Order>> {
  StreamSubscription? _subscription;
  String? _activeFactoryId;
  bool _isListening = false;

  @override
  List<Order> build() {
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
        ref.read(ordersLoadedProvider.notifier).state = false;
      });
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;
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

            final byId =
                customers.firstWhereOrNull((c) => c.id == o.customerId);
            final idRoute = byId?.assignedRoute?.trim();
            if (idRoute?.isNotEmpty == true) return idRoute;

            final phone = o.customerPhone.trim();
            if (phone.isNotEmpty) {
              final byPhone =
                  customers.firstWhereOrNull((c) => c.phone.trim() == phone);
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
            final route =
                routes.firstWhereOrNull((r) => r.id == k || r.name == k);
            return route == null ? k : route.id;
          }

          state = snapshot.docs
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
                if (normalizedId == null || normalizedId.isEmpty) return o;
                if (o.assignedRoute?.trim() == normalizedId) return o;
                return o.copyWith(assignedRoute: normalizedId);
              })
              .toList();
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

  void addOrder(Order order) => FirebaseService.firestore
      .collection('orders')
      .doc(order.id)
      .set(order.toJson());
  void updateOrder(Order order) => FirebaseService.firestore
      .collection('orders')
      .doc(order.id)
      .set(order.toJson());
  void deleteOrder(String id) =>
      FirebaseService.firestore.collection('orders').doc(id).delete();

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
