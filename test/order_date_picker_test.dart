import 'package:delivero/core/orders/business_day.dart';
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

    test(
      'midnight _orderDate converts correctly to business-day timestamp',
      () {
        final midnight = DateTime(
          2026,
          6,
          21,
          0,
          0,
        ); // hour=0 → would roll back before fix
        const rolloverHour = 19;
        final converted = orderDateForBusinessDay(
          midnight,
          rolloverHour: rolloverHour,
        );
        // converted should be June 21 at 19:00 → maps to June 21 business day
        expect(
          businessDayKey(converted, rolloverHour: rolloverHour),
          equals(DateTime(2026, 6, 21)),
        );
        // midnight itself would map to June 20 — confirm the bug existed
        expect(
          businessDayKey(midnight, rolloverHour: rolloverHour),
          equals(DateTime(2026, 6, 20)),
        );
      },
    );
  });
}
