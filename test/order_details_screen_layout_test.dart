import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delivero/app/order_settings_provider.dart';
import 'package:delivero/app/providers.dart';
import 'package:delivero/core/theme/app_theme.dart';
import 'package:delivero/data/models/customer.dart';
import 'package:delivero/data/models/delivery_route.dart';
import 'package:delivero/data/models/driver.dart';
import 'package:delivero/data/models/food_item.dart';
import 'package:delivero/data/models/order.dart';
import 'package:delivero/data/models/user.dart';
import 'package:delivero/features/auth/auth_controller.dart';
import 'package:delivero/features/owner/orders/order_details/order_details_screen.dart';

/// Mirrors the real ORD-4583 on the device: pending, unpaid, two line items.
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
      OrderItem(
        id: 'l2',
        foodItemId: 'i1',
        foodItemName: 'appam',
        quantity: 52,
        unitPrice: 12,
        totalPrice: 624,
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
  List<Customer> build() => const [];
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
  List<DeliveryRoute> build() => const [];
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
  testWidgets('order details screen lays out end to end', (tester) async {
    // The RMX2151 the bug reproduces on: 1080x2400 at dpr 3, with a status bar.
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

    // The app's own theme, not the default one: it sets outlined buttons to
    // full width (minimumSize.width == infinity), which is what breaks the
    // bottom bar's unflexed "More" button.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const OrderDetailsScreen(orderId: 'ORD-4583'),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Order Details'), findsOneWidget);
    expect(find.text('#ORD-4583'), findsOneWidget);
  });
}
