import 'package:delivero/core/orders/order_merge.dart';
import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/production_test_data.dart';

void main() {
  group('order date picker — merge logic', () {
    // When _orderDate is a future date, findMergeTargetOrder must return null
    // even if an order exists for today. This is the core correctness guarantee
    // of passing _orderDate as referenceTime instead of DateTime.now().
    test('future referenceTime does not merge with today\'s order', () {
      final todayOrder = productionTestOrder(
        id: 'today',
        orderDate: DateTime(2026, 6, 21, 9),
        deliveryRun: DeliveryRun.morning,
      );
      // referenceTime = tomorrow; today's order is on a different business day
      final result = findMergeTargetOrder(
        orders: [todayOrder],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: DateTime(2026, 6, 22, 9),
      );
      expect(result, isNull);
    });

    test('same-day referenceTime merges as before', () {
      final todayOrder = productionTestOrder(
        id: 'today',
        orderDate: DateTime(2026, 6, 21, 9),
        deliveryRun: DeliveryRun.morning,
      );
      final result = findMergeTargetOrder(
        orders: [todayOrder],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: DateTime(2026, 6, 21, 11),
      );
      expect(result?.id, 'today');
    });

    test('past referenceTime merges with matching past order', () {
      final pastOrder = productionTestOrder(
        id: 'yesterday',
        orderDate: DateTime(2026, 6, 20, 9),
        deliveryRun: DeliveryRun.morning,
      );
      final result = findMergeTargetOrder(
        orders: [pastOrder],
        customerId: 'cust-1',
        orderType: OrderType.daily,
        deliveryRun: DeliveryRun.morning,
        referenceTime: DateTime(2026, 6, 20, 14),
      );
      expect(result?.id, 'yesterday');
    });
  });
}
