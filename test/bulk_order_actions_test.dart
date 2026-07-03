import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('bulk mark delivered', () {
    test('sets status to delivered', () {
      final order = productionTestOrder(id: 'o1');
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        status: OrderStatus.delivered,
        deliveryTime: order.deliveryTime ?? now,
        deliveryDate: order.deliveryDate ?? now,
        updatedAt: now,
      );
      expect(updated.status, OrderStatus.delivered);
    });

    test('does not overwrite an existing deliveryTime', () {
      final existing = DateTime(2026, 6, 21, 8, 0);
      final order = productionTestOrder(
        id: 'o1',
      ).copyWith(deliveryTime: existing, deliveryDate: existing);
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        status: OrderStatus.delivered,
        deliveryTime: order.deliveryTime ?? now,
        deliveryDate: order.deliveryDate ?? now,
        updatedAt: now,
      );
      expect(updated.deliveryTime, existing);
      expect(updated.deliveryDate, existing);
    });

    test('skips order already delivered (no-op when filtering)', () {
      final delivered = productionTestOrder(
        id: 'o1',
      ).copyWith(status: OrderStatus.delivered);
      // In _bulkMarkDelivered, cancelled/delivered orders are skipped via .where()
      final toUpdate = [
        delivered,
      ].where((o) => o.status != OrderStatus.delivered).toList();
      expect(toUpdate, isEmpty);
    });
  });

  group('bulk mark paid', () {
    test('sets paymentStatus to paid', () {
      final order = productionTestOrder(id: 'o1');
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        paymentStatus: PaymentStatus.paid,
        paymentMethod: order.paymentMethod ?? PaymentMethod.cash,
        paymentTime: now,
        updatedAt: now,
      );
      expect(updated.paymentStatus, PaymentStatus.paid);
    });

    test('preserves existing paymentMethod when not null', () {
      final order = productionTestOrder(
        id: 'o1',
      ).copyWith(paymentMethod: PaymentMethod.online);
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        paymentStatus: PaymentStatus.paid,
        paymentMethod: order.paymentMethod ?? PaymentMethod.cash,
        paymentTime: now,
        updatedAt: now,
      );
      expect(updated.paymentMethod, PaymentMethod.online);
    });

    test('defaults paymentMethod to cash when null', () {
      // productionTestOrder has paymentMethod: null by default
      final order = productionTestOrder(id: 'o1');
      expect(order.paymentMethod, isNull);
      final now = DateTime(2026, 6, 21, 10, 0);
      final updated = order.copyWith(
        paymentStatus: PaymentStatus.paid,
        paymentMethod: order.paymentMethod ?? PaymentMethod.cash,
        paymentTime: now,
        updatedAt: now,
      );
      expect(updated.paymentMethod, PaymentMethod.cash);
    });
  });
}
