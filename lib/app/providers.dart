import 'dart:async';

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

// Notifiers for domain states

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
        (_, next) => _setFactoryId(next.asData?.value),
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
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;

    _subscription = FirebaseService.firestore
        .collection('orders')
        .where('factoryId', isEqualTo: factoryId)
        .snapshots()
        .listen(
          (snapshot) {
            state = snapshot.docs
                .map((doc) => Order.fromJson({...doc.data(), 'id': doc.id}))
                .toList();
          },
          onError: (e) {
            debugPrint('[Firestore] Error fetching orders: $e');
          },
        );
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
        (_, next) => _setFactoryId(next.asData?.value),
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
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;

    _subscription = FirebaseService.firestore
        .collection('customers')
        .where('factoryId', isEqualTo: factoryId)
        .snapshots()
        .listen(
          (snapshot) {
            state = snapshot.docs
                .map((doc) => Customer.fromJson({...doc.data(), 'id': doc.id}))
                .toList();
          },
          onError: (e) {
            debugPrint('[Firestore] Error fetching customers: $e');
          },
        );
  }

  void addCustomer(Customer customer) => FirebaseService.firestore
      .collection('customers')
      .doc(customer.id)
      .set(customer.toJson());
  void updateCustomer(Customer customer) => FirebaseService.firestore
      .collection('customers')
      .doc(customer.id)
      .set(customer.toJson());
  void deleteCustomer(String id) =>
      FirebaseService.firestore.collection('customers').doc(id).delete();
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
        (_, next) => _setFactoryId(next.asData?.value),
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
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;

    _subscription = FirebaseService.firestore
        .collection('foodItems')
        .where('factoryId', isEqualTo: factoryId)
        .snapshots()
        .listen(
          (snapshot) {
            state = snapshot.docs
                .map((doc) => FoodItem.fromJson({...doc.data(), 'id': doc.id}))
                .toList();
          },
          onError: (e) {
            debugPrint('[Firestore] Error fetching food items: $e');
          },
        );
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
        (_, next) => _setFactoryId(next.asData?.value),
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
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;

    _subscription = FirebaseService.firestore
        .collection('routes')
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
          },
          onError: (e) {
            debugPrint('[Firestore] Error fetching routes: $e');
          },
        );
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
        (_, next) => _setFactoryId(next.asData?.value),
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
      return;
    }

    if (_activeFactoryId == factoryId && _subscription != null) return;

    _subscription?.cancel();
    _activeFactoryId = factoryId;

    _subscription = FirebaseService.firestore
        .collection('drivers')
        .where('factoryId', isEqualTo: factoryId)
        .snapshots()
        .listen(
          (snapshot) {
            state = snapshot.docs
                .map((doc) => Driver.fromJson({...doc.data(), 'id': doc.id}))
                .toList();
          },
          onError: (e) {
            debugPrint('[Firestore] Error fetching drivers: $e');
          },
        );
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
}
