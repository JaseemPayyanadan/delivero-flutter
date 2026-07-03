import 'package:delivero/core/orders/order_merge.dart';
import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/production_test_data.dart';

void main() {
  final day = DateTime(2025, 6, 20, 9);

  group('findMergeTargetOrder', () {
    test('merges same customer, type, day, and delivery run', () {
      final morning = productionTestOrder(
        id: 'morning',
        orderDate: day,
        deliveryRun: DeliveryRun.morning,
      );
      final target = findMergeTargetOrder(
        orders: [morning],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: day.add(const Duration(hours: 2)),
      );
      expect(target?.id, 'morning');
    });

    test('does not merge different delivery run on same day', () {
      final morning = productionTestOrder(
        id: 'morning',
        orderDate: day,
        deliveryRun: DeliveryRun.morning,
      );
      final target = findMergeTargetOrder(
        orders: [morning],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.evening,
        referenceTime: day.add(const Duration(hours: 10)),
      );
      expect(target, isNull);
    });

    test('ignores delivered orders', () {
      final delivered = productionTestOrder(
        id: 'done',
        orderDate: day,
        status: OrderStatus.delivered,
        deliveryRun: DeliveryRun.morning,
      );
      final target = findMergeTargetOrder(
        orders: [delivered],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: day,
      );
      expect(target, isNull);
    });

    test('ignores confirmed orders — kitchen already has it', () {
      final confirmed = productionTestOrder(
        id: 'conf',
        orderDate: day,
        status: OrderStatus.confirmed,
        deliveryRun: DeliveryRun.morning,
      );
      final target = findMergeTargetOrder(
        orders: [confirmed],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: day.add(const Duration(hours: 2)),
      );
      expect(target, isNull);
    });

    test('ignores preparing orders', () {
      final preparing = productionTestOrder(
        id: 'prep',
        orderDate: day,
        status: OrderStatus.preparing,
        deliveryRun: DeliveryRun.morning,
      );
      final target = findMergeTargetOrder(
        orders: [preparing],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: day.add(const Duration(hours: 2)),
      );
      expect(target, isNull);
    });

    test('ignores ready orders', () {
      final ready = productionTestOrder(
        id: 'rdy',
        orderDate: day,
        status: OrderStatus.ready,
        deliveryRun: DeliveryRun.morning,
      );
      final target = findMergeTargetOrder(
        orders: [ready],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: day.add(const Duration(hours: 2)),
      );
      expect(target, isNull);
    });

    test('does not merge across 7 AM business-day reset', () {
      final beforeSeven = productionTestOrder(
        id: 'early',
        orderDate: DateTime(2025, 6, 20, 6, 30),
        deliveryRun: DeliveryRun.morning,
      );
      final target = findMergeTargetOrder(
        orders: [beforeSeven],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: DateTime(2025, 6, 20, 8),
        rolloverHour: 7,
      );
      expect(target, isNull);
    });

    test('merges after 7 AM within same business day', () {
      final afterSeven = productionTestOrder(
        id: 'late',
        orderDate: DateTime(2025, 6, 20, 7, 15),
        deliveryRun: DeliveryRun.morning,
      );
      final target = findMergeTargetOrder(
        orders: [afterSeven],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: DateTime(2025, 6, 20, 9),
        rolloverHour: 7,
      );
      expect(target?.id, 'late');
    });

    test('returns null for special orders', () {
      final open = productionTestOrder(
        id: 'open',
        orderDate: day,
        deliveryRun: DeliveryRun.morning,
      );
      final target = findMergeTargetOrder(
        orders: [open],
        customerId: 'cust-1',
        orderType: OrderType.special,
        deliveryRun: DeliveryRun.morning,
        referenceTime: day,
      );
      expect(target, isNull);
    });
  });

  group('DeliveryRun parsing', () {
    test('defaults to morning when missing', () {
      final order = Order.fromJson({
        'id': 'o1',
        'factoryId': 'f1',
        'orderType': 'daily',
        'customerId': 'c1',
        'customerName': 'Cafe',
        'items': [],
        'subtotal': 0,
        'discountAmount': 0,
        'totalAmount': 0,
        'status': 'pending',
        'orderDate': '2025-06-20T10:00:00.000',
        'createdAt': '2025-06-20T10:00:00.000',
        'updatedAt': '2025-06-20T10:00:00.000',
      });
      expect(order.deliveryRun, DeliveryRun.morning);
    });

    test('reads deliveryRun from json', () {
      final order = Order.fromJson({
        'id': 'o1',
        'factoryId': 'f1',
        'orderType': 'daily',
        'deliveryRun': 'evening',
        'customerId': 'c1',
        'customerName': 'Cafe',
        'items': [],
        'subtotal': 0,
        'discountAmount': 0,
        'totalAmount': 0,
        'status': 'pending',
        'orderDate': '2025-06-20T10:00:00.000',
        'createdAt': '2025-06-20T10:00:00.000',
        'updatedAt': '2025-06-20T10:00:00.000',
      });
      expect(order.deliveryRun, DeliveryRun.evening);
    });
  });
}
