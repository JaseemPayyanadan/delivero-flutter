import 'package:delivero/core/orders/business_day.dart';
import 'package:delivero/core/orders/daily_order_recreation_service.dart';
import 'package:delivero/data/models/customer.dart';
import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/production_test_data.dart';

void main() {
  const rolloverHour = 7;
  final day1Morning = DateTime(2025, 6, 20, 9);
  final day2Morning = DateTime(2025, 6, 21, 9);

  Customer activeCustomer() => Customer(
    id: 'cust-1',
    factoryId: 'FAC_001',
    name: 'Test Cafe',
    email: '',
    phone: '9999999999',
    address: '123 Main St',
    area: 'North',
    isActive: true,
    createdAt: day1Morning,
    updatedAt: day1Morning,
  );

  Customer inactiveCustomer() => Customer(
    id: 'cust-2',
    factoryId: 'FAC_001',
    name: 'Closed Cafe',
    email: '',
    phone: '8888888888',
    address: '456 Side St',
    area: 'South',
    isActive: false,
    createdAt: day1Morning,
    updatedAt: day1Morning,
  );

  group('runBatchForTargetDay', () {
    test('creates pending order from yesterday pending daily order', () {
      final pending = productionTestOrder(
        id: 'src-pending',
        orderDate: day1Morning,
        status: OrderStatus.pending,
      );
      final created = <Order>[];

      final result = runBatchForTargetDay(
        targetBusinessDay: DateTime(2025, 6, 21),
        orders: [pending],
        customers: [activeCustomer()],
        rolloverHour: rolloverHour,
        addOrder: created.add,
      );

      expect(result.createdCount, 1);
      expect(created.first.recreatedFromOrderId, 'src-pending');
      expect(created.first.status, OrderStatus.pending);
    });

    test('creates pending order from yesterday delivered daily order', () {
      final delivered = productionTestOrder(
        id: 'src-1',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
      );
      final created = <Order>[];

      final result = runBatchForTargetDay(
        targetBusinessDay: DateTime(2025, 6, 21),
        orders: [delivered],
        customers: [activeCustomer()],
        rolloverHour: rolloverHour,
        addOrder: created.add,
      );

      expect(result.createdCount, 1);
      expect(created, hasLength(1));
      expect(created.first.status, OrderStatus.pending);
      expect(created.first.recreatedFromOrderId, 'src-1');
      expect(created.first.paymentStatus, PaymentStatus.unpaid);
      expect(
        businessDayKey(created.first.orderDate, rolloverHour: rolloverHour),
        DateTime(2025, 6, 21),
      );
    });

    test('skips when open order already exists for target day', () {
      final delivered = productionTestOrder(
        id: 'src-1',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
      );
      final existing = productionTestOrder(
        id: 'existing',
        orderDate: day2Morning,
        status: OrderStatus.pending,
      );
      final created = <Order>[];

      final result = runBatchForTargetDay(
        targetBusinessDay: DateTime(2025, 6, 21),
        orders: [delivered, existing],
        customers: [activeCustomer()],
        rolloverHour: rolloverHour,
        addOrder: created.add,
      );

      expect(result.createdCount, 0);
      expect(created, isEmpty);
    });

    test('skips one-time, special, cancelled, and inactive customers', () {
      final oneTime = productionTestOrder(
        id: 'one-time',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
        orderType: OrderType.oneTime,
      );
      final special = productionTestOrder(
        id: 'special',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
        orderType: OrderType.special,
      );
      final cancelled = productionTestOrder(
        id: 'cancelled',
        orderDate: day1Morning,
        status: OrderStatus.cancelled,
      );
      final inactive = productionTestOrder(
        id: 'inactive',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
      ).copyWith(customerId: 'cust-2');
      final created = <Order>[];

      final result = runBatchForTargetDay(
        targetBusinessDay: DateTime(2025, 6, 21),
        orders: [oneTime, special, cancelled, inactive],
        customers: [activeCustomer(), inactiveCustomer()],
        rolloverHour: rolloverHour,
        addOrder: created.add,
      );

      expect(result.createdCount, 0);
    });

    test('creates separate orders per delivery run', () {
      final morning = productionTestOrder(
        id: 'morning',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
        deliveryRun: DeliveryRun.morning,
      );
      final evening = productionTestOrder(
        id: 'evening',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
        deliveryRun: DeliveryRun.evening,
      );
      final created = <Order>[];

      final result = runBatchForTargetDay(
        targetBusinessDay: DateTime(2025, 6, 21),
        orders: [morning, evening],
        customers: [activeCustomer()],
        rolloverHour: rolloverHour,
        addOrder: created.add,
      );

      expect(result.createdCount, 2);
    });
  });

  group('syncNextDayFromSource', () {
    test('updates pending next-day order when pending source changes', () {
      final pending = productionTestOrder(
        id: 'src-1',
        orderDate: day1Morning,
        status: OrderStatus.pending,
        items: [
          OrderItem(
            id: 'line-1',
            foodItemId: 'food-1',
            foodItemName: 'Japathi',
            quantity: 25,
            unitPrice: 10,
            totalPrice: 250,
          ),
        ],
      ).copyWith(subtotal: 250, totalAmount: 250);
      final nextDay = productionTestOrder(
        id: 'next-1',
        orderDate: day2Morning,
        status: OrderStatus.pending,
      ).copyWith(recreatedFromOrderId: 'src-1');
      Order? updated;

      final result = syncNextDayFromSource(
        source: pending,
        orders: [pending, nextDay],
        customers: [activeCustomer()],
        rolloverHour: rolloverHour,
        updateOrder: (o) => updated = o,
      );

      expect(result?.syncedCount, 1);
      expect(updated?.items.first.quantity, 25);
    });

    test('updates pending next-day order when delivered source changes', () {
      final delivered = productionTestOrder(
        id: 'src-1',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
        items: [
          OrderItem(
            id: 'line-1',
            foodItemId: 'food-1',
            foodItemName: 'Japathi',
            quantity: 30,
            unitPrice: 10,
            totalPrice: 300,
          ),
        ],
      ).copyWith(subtotal: 300, totalAmount: 300);
      final nextDay = productionTestOrder(
        id: 'next-1',
        orderDate: day2Morning,
        status: OrderStatus.pending,
      ).copyWith(recreatedFromOrderId: 'src-1');
      Order? updated;

      final result = syncNextDayFromSource(
        source: delivered,
        orders: [delivered, nextDay],
        customers: [activeCustomer()],
        rolloverHour: rolloverHour,
        updateOrder: (o) => updated = o,
      );

      expect(result?.syncedCount, 1);
      expect(updated?.items.first.quantity, 30);
      expect(updated?.totalAmount, 300);
    });

    test('does not overwrite confirmed next-day order', () {
      final delivered = productionTestOrder(
        id: 'src-1',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
      );
      final confirmed = productionTestOrder(
        id: 'next-1',
        orderDate: day2Morning,
        status: OrderStatus.confirmed,
      ).copyWith(recreatedFromOrderId: 'src-1');
      var updateCount = 0;

      final result = syncNextDayFromSource(
        source: delivered,
        orders: [delivered, confirmed],
        customers: [activeCustomer()],
        rolloverHour: rolloverHour,
        updateOrder: (_) => updateCount++,
      );

      expect(result, isNull);
      expect(updateCount, 0);
    });

    test('cancels linked pending order when source is cancelled', () {
      final cancelled = productionTestOrder(
        id: 'src-1',
        orderDate: day1Morning,
        status: OrderStatus.cancelled,
      );
      final pending = productionTestOrder(
        id: 'next-1',
        orderDate: day2Morning,
        status: OrderStatus.pending,
      ).copyWith(recreatedFromOrderId: 'src-1');
      Order? updated;

      final result = syncNextDayFromSource(
        source: cancelled,
        orders: [cancelled, pending],
        customers: [activeCustomer()],
        rolloverHour: rolloverHour,
        updateOrder: (o) => updated = o,
      );

      expect(result?.cancelledCount, 1);
      expect(updated?.status, OrderStatus.cancelled);
    });
  });

  group('ensureRecreatedOrderIsPending', () {
    test('forces pending and clears delivery/payment fields', () {
      final delivered = productionTestOrder(
        id: 'src-1',
        orderDate: day1Morning,
        status: OrderStatus.delivered,
      ).copyWith(
        recreatedFromOrderId: 'parent',
        paymentStatus: PaymentStatus.paid,
        deliveryDate: day1Morning,
        deliveryTime: day1Morning,
      );

      final normalized = ensureRecreatedOrderIsPending(delivered);

      expect(normalized.status, OrderStatus.pending);
      expect(normalized.paymentStatus, PaymentStatus.unpaid);
      expect(normalized.deliveryDate, isNull);
      expect(normalized.deliveryTime, isNull);
    });
  });

  group('business day helpers', () {
    test('previousBusinessDayKey subtracts one calendar day', () {
      final key = previousBusinessDayKey(
        DateTime(2025, 6, 21, 10),
        rolloverHour: rolloverHour,
      );
      expect(key, DateTime(2025, 6, 20));
    });

    test('hasPassedBusinessDayRollover is false before cutoff', () {
      expect(
        hasPassedBusinessDayRollover(
          DateTime(2025, 6, 21, 6, 30),
          rolloverHour: rolloverHour,
        ),
        isFalse,
      );
    });
  });
}
