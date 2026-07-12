import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:delivero/app/providers.dart';
import 'package:delivero/core/theme/app_theme.dart';
import 'package:delivero/data/models/customer.dart';
import 'package:delivero/data/models/delivery_route.dart';
import 'package:delivero/data/models/food_item.dart';
import 'package:delivero/data/models/order.dart';
import 'package:delivero/features/owner/customers/customer_details/customer_details_screen.dart';

Customer _fullCustomer() => Customer(
  id: 'c1',
  factoryId: 'f1',
  name: 'Rahul Kumar',
  email: 'rahul@example.com',
  phone: '9876543210',
  address: 'Ottappalam, Palakkad, Kerala',
  area: 'Palakkad',
  ownerName: 'Rahul',
  discountPercentage: 10,
  isActive: true,
  products: const [CustomerProduct(id: 'i1', name: 'appam', quantity: 100)],
  createdAt: DateTime(2025, 3, 4),
  updatedAt: DateTime(2025, 3, 4),
);

Customer _minimalCustomer() => Customer(
  id: 'c2',
  factoryId: 'f1',
  name: 'Anon',
  email: '',
  phone: '',
  address: '',
  area: '',
  isActive: false,
  createdAt: DateTime(2025, 3, 4),
  updatedAt: DateTime(2025, 3, 4),
);

Order _order() {
  final now = DateTime.now();
  return Order(
    id: 'ORD-4583',
    factoryId: 'f1',
    orderType: OrderType.daily,
    customerId: 'c1',
    customerName: 'Rahul Kumar',
    customerEmail: '',
    customerPhone: '9876543210',
    customerAddress: 'Ottappalam',
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
    subtotal: 1200,
    discountAmount: 0,
    totalAmount: 1200,
    status: OrderStatus.pending,
    paymentStatus: PaymentStatus.unpaid,
    orderDate: now,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeCustomers extends CustomersNotifier {
  @override
  List<Customer> build() => [_fullCustomer(), _minimalCustomer()];
}

class _FakeOrders extends OrdersNotifier {
  @override
  List<Order> build() => [_order()];
}

class _FakeFoodItems extends FoodItemsNotifier {
  @override
  List<FoodItem> build() => const [];
}

class _FakeRoutes extends RoutesNotifier {
  @override
  List<DeliveryRoute> build() => const [];
}

Future<void> _pumpScreen(WidgetTester tester, String customerId) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = const FakeViewPadding(top: 72, bottom: 48);
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      customersProvider.overrideWith(_FakeCustomers.new),
      ordersProvider.overrideWith(_FakeOrders.new),
      foodItemsProvider.overrideWith(_FakeFoodItems.new),
      routesProvider.overrideWith(_FakeRoutes.new),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: CustomerDetailsScreen(customerId: customerId),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('customer details lays out with every field populated', (
    tester,
  ) async {
    await _pumpScreen(tester, 'c1');

    expect(tester.takeException(), isNull);
    expect(find.text('Rahul Kumar'), findsWidgets);
    expect(find.text('Financial'), findsOneWidget);
    expect(find.text('Recurring order'), findsOneWidget);
    expect(find.text('Order history'), findsOneWidget);
    expect(find.text('Contact & info'), findsOneWidget);
    // Identity card: owner name and address sit up top, status rides the
    // avatar ring and the meta line.
    expect(find.text('Rahul'), findsOneWidget);
    expect(find.text('Ottappalam, Palakkad, Kerala'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.bySemanticsLabel('Call 9876543210'), findsOneWidget);
    // Owner and address are no longer duplicated in Contact & info.
    expect(find.text('Owner / Manager'), findsNothing);
    expect(find.text('Address'), findsNothing);
    // Financial headline.
    expect(find.text('OUTSTANDING'), findsOneWidget);
    expect(find.text('Balance to collect'), findsOneWidget);
    expect(find.text('New order'), findsOneWidget);
  });

  testWidgets('customer details lays out with no contacts, items, or orders', (
    tester,
  ) async {
    await _pumpScreen(tester, 'c2');

    expect(tester.takeException(), isNull);
    expect(find.text('No recurring items set yet.'), findsOneWidget);
    expect(find.text('No orders yet'), findsOneWidget);
    expect(find.text('New order'), findsOneWidget);
    expect(find.text('All settled up'), findsOneWidget);
  });

  testWidgets('Collect lists the orders that still owe money', (tester) async {
    await _pumpScreen(tester, 'c1');

    await tester.tap(find.text('Collect'));
    await tester.pumpAndSettle();

    expect(find.text('Collect payment'), findsOneWidget);
    expect(find.text('#ORD-4583'), findsOneWidget);
  });
}
