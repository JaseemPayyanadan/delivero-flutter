import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delivero/app/order_settings_provider.dart';
import 'package:delivero/app/providers.dart';
import 'package:delivero/data/models/customer.dart';
import 'package:delivero/data/models/delivery_route.dart';
import 'package:delivero/data/models/driver.dart';
import 'package:delivero/data/models/food_item.dart';
import 'package:delivero/data/models/order.dart';
import 'package:delivero/data/models/user.dart';
import 'package:delivero/features/auth/auth_controller.dart';
import 'package:delivero/features/owner/owner_shell.dart';

Order _order() {
  final now = DateTime.now();
  return Order(
    id: 'ORD-4583',
    factoryId: 'f1',
    orderType: OrderType.daily,
    customerId: 'c1',
    customerName: 'wbc',
    customerEmail: '',
    customerPhone: '9876543210',
    customerAddress: 'Ottappalam, Palakkad, Kerala',
    items: const [
      OrderItem(
        id: 'l1',
        foodItemId: 'i1',
        foodItemName: 'appam',
        quantity: 100,
        unitPrice: 12,
        totalPrice: 1200,
      ),
    ],
    subtotal: 1824,
    discountAmount: 0,
    totalAmount: 1824,
    status: OrderStatus.pending,
    paymentStatus: PaymentStatus.unpaid,
    orderDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeOrders extends OrdersNotifier {
  @override
  List<Order> build() => [_order()];
}

class _FakeCustomers extends CustomersNotifier {
  @override
  List<Customer> build() {
    final now = DateTime.now();
    return [
      Customer(
        id: 'c1',
        factoryId: 'f1',
        name: 'wbc',
        email: '',
        phone: '9876543210',
        address: 'Ottappalam, Palakkad, Kerala',
        area: 'hsr',
        isActive: true,
        assignedRoute: 'r1',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

class _FakeDrivers extends DriversNotifier {
  @override
  List<Driver> build() => const [];
}

class _FakeFoodItems extends FoodItemsNotifier {
  @override
  List<FoodItem> build() => const [];
}

class _FakeRoutes extends RoutesNotifier {
  @override
  List<DeliveryRoute> build() {
    final now = DateTime.now();
    return [
      DeliveryRoute(
        id: 'r1',
        factoryId: 'f1',
        name: 'hsr',
        description: '',
        area: 'hsr',
        isActive: true,
        estimatedDeliveryTime: 30,
        maxOrders: 50,
        currentOrders: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}

class _FakeRolloverHour extends OrderRolloverHourNotifier {
  @override
  int build() => 0;
}

class _FakeAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: User(
      id: 'u1',
      phone: '9497557401',
      name: 'Jaseem',
      role: UserRole.owner,
      factoryId: 'f1',
      hasFinishedOnboarding: true,
    ),
    isInitialized: true,
  );
}

void main() {
  testWidgets(
    'owner shell lays out every tab (IndexedStack keeps them all alive)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          ordersProvider.overrideWith(_FakeOrders.new),
          customersProvider.overrideWith(_FakeCustomers.new),
          driversProvider.overrideWith(_FakeDrivers.new),
          foodItemsProvider.overrideWith(_FakeFoodItems.new),
          routesProvider.overrideWith(_FakeRoutes.new),
          orderRolloverHourProvider.overrideWith(_FakeRolloverHour.new),
          authProvider.overrideWith(_FakeAuth.new),
        ],
      );
      addTearDown(container.dispose);

      for (final flag in [
        ordersLoadedProvider,
        customersLoadedProvider,
        driversLoadedProvider,
        foodItemsLoadedProvider,
        routesLoadedProvider,
      ]) {
        // ignore: invalid_use_of_protected_member
        container.read(flag.notifier).state = true;
      }

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: OwnerShell()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
