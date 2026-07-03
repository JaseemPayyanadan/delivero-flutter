import 'package:flutter_test/flutter_test.dart';

import 'package:delivero/core/orders/split_order_label.dart';
import 'package:delivero/data/models/order.dart';

Order _testOrder({
  required String id,
  required String customerId,
  required DateTime orderDate,
  DeliveryRun deliveryRun = DeliveryRun.morning,
}) {
  return Order(
    id: id,
    factoryId: 'factory-1',
    orderType: OrderType.daily,
    deliveryRun: deliveryRun,
    customerId: customerId,
    customerName: 'Customer',
    customerEmail: '',
    customerPhone: '',
    customerAddress: '',
    items: const [],
    subtotal: 0,
    discountAmount: 0,
    totalAmount: 0,
    status: OrderStatus.pending,
    orderDate: orderDate,
    createdAt: orderDate,
    updatedAt: orderDate,
  );
}

void main() {
  group('splitBoxSubtitle', () {
    final day = DateTime(2026, 6, 6, 10);

    test('returns box index when multiple orders share customer and run', () {
      final orders = [
        _testOrder(id: 'o1', customerId: 'c1', orderDate: day),
        _testOrder(
          id: 'o2',
          customerId: 'c1',
          orderDate: day.add(const Duration(hours: 1)),
        ),
      ];

      expect(splitBoxSubtitle(orders[0], orders), 'Box 1 of 2');
      expect(splitBoxSubtitle(orders[1], orders), 'Box 2 of 2');
    });

    test('returns null for a single order', () {
      final orders = [_testOrder(id: 'o1', customerId: 'c1', orderDate: day)];
      expect(splitBoxSubtitle(orders.first, orders), isNull);
    });
  });
}
