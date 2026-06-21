import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('date section revenue totals', () {
    test('fold sums totalAmount across orders in a group', () {
      final orders = [
        productionTestOrder(id: 'a'),
        productionTestOrder(id: 'b'),
        productionTestOrder(id: 'c'),
      ];
      // productionTestOrder sets totalAmount to 200.0
      final dayTotal = orders.fold(0.0, (sum, o) => sum + o.totalAmount);
      expect(dayTotal, 600.0);
    });

    test('empty order list yields dayTotal of 0', () {
      final orders = <Order>[];
      final dayTotal = orders.fold(0.0, (sum, o) => sum + o.totalAmount);
      expect(dayTotal, 0.0);
    });

    test('single order day total equals its totalAmount', () {
      final order = productionTestOrder(id: 'solo');
      final dayTotal = [order].fold(0.0, (sum, o) => sum + o.totalAmount);
      expect(dayTotal, order.totalAmount);
    });
  });
}
