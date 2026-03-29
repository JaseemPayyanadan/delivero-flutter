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
  @override
  List<Order> build() {
    final factoryIdAsync = ref.watch(factoryIdProvider);
    factoryIdAsync.whenData((id) {
      if (id != null) _init(id);
    });
    return [];
  }

  Future<void> _init(String factoryId) async {
    FirebaseService.firestore
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
  @override
  List<Customer> build() {
    final factoryIdAsync = ref.watch(factoryIdProvider);
    factoryIdAsync.whenData((id) {
      if (id != null) _init(id);
    });
    return [];
  }

  Future<void> _init(String factoryId) async {
    FirebaseService.firestore
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
  @override
  List<FoodItem> build() {
    final factoryIdAsync = ref.watch(factoryIdProvider);
    factoryIdAsync.whenData((id) {
      if (id != null) _init(id);
    });
    return [];
  }

  Future<void> _init(String factoryId) async {
    FirebaseService.firestore
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
  @override
  List<DeliveryRoute> build() {
    final factoryIdAsync = ref.watch(factoryIdProvider);
    factoryIdAsync.whenData((id) {
      if (id != null) _init(id);
    });
    return [];
  }

  Future<void> _init(String factoryId) async {
    FirebaseService.firestore
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
  @override
  List<Driver> build() {
    final factoryIdAsync = ref.watch(factoryIdProvider);
    factoryIdAsync.whenData((id) {
      if (id != null) _init(id);
    });
    return [];
  }

  Future<void> _init(String factoryId) async {
    FirebaseService.firestore
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
}
