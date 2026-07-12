import 'package:delivero/core/orders/order_sort.dart';
import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a daily order with the fields that drive within-day sorting.
/// [createdAt] defaults to [orderDate] but can be varied to simulate the
/// daily recreation service stamping fresh timestamps each morning.
Order orderOn(
  DateTime orderDate, {
  required String route,
  required String name,
  DateTime? createdAt,
}) {
  return Order(
    id: '$route-$name-${orderDate.toIso8601String()}',
    factoryId: 'FAC_001',
    orderType: OrderType.daily,
    customerId: name,
    customerName: name,
    customerEmail: '',
    customerPhone: '',
    customerAddress: '',
    items: const [],
    subtotal: 0,
    discountAmount: 0,
    totalAmount: 0,
    status: OrderStatus.pending,
    assignedRoute: route,
    orderDate: orderDate,
    createdAt: createdAt ?? orderDate,
    updatedAt: createdAt ?? orderDate,
  );
}

/// The visible sequence of a day's list, as customer names.
List<String> sequence(List<Order> orders) {
  final copy = [...orders]..sort((a, b) => compareOrdersByDate(a, b));
  return copy.map((o) => o.customerName).toList();
}

void main() {
  group('compareOrdersByDate within a single day', () {
    test('orders by route then customer name, ignoring createdAt', () {
      final day = DateTime(2025, 6, 13, 9);
      // Deliberately scramble insertion order and createdAt.
      final orders = [
        orderOn(day, route: 'route-2', name: 'Zara', createdAt: DateTime(2025, 6, 13, 5, 0, 0, 1)),
        orderOn(day, route: 'route-1', name: 'Beans', createdAt: DateTime(2025, 6, 13, 5, 0, 0, 9)),
        orderOn(day, route: 'route-1', name: 'Anna', createdAt: DateTime(2025, 6, 13, 5, 0, 0, 4)),
        orderOn(day, route: 'route-2', name: 'Amir', createdAt: DateTime(2025, 6, 13, 5, 0, 0, 2)),
      ];

      expect(sequence(orders), ['Anna', 'Beans', 'Amir', 'Zara']);
    });

    test('unassigned route sorts to the bottom of the day', () {
      final day = DateTime(2025, 6, 13, 9);
      final orders = [
        Order(
          id: 'no-route',
          factoryId: 'FAC_001',
          orderType: OrderType.daily,
          customerId: 'Mo',
          customerName: 'Mo',
          customerEmail: '',
          customerPhone: '',
          customerAddress: '',
          items: const [],
          subtotal: 0,
          discountAmount: 0,
          totalAmount: 0,
          status: OrderStatus.pending,
          assignedRoute: null,
          orderDate: day,
          createdAt: day,
          updatedAt: day,
        ),
        orderOn(day, route: 'route-1', name: 'Anna'),
      ];

      expect(sequence(orders), ['Anna', 'Mo']);
    });

    test(
      'recreation with fresh createdAt keeps the SAME sequence every day',
      () {
        // June 13: the source day. Same customers/routes each day.
        final customers = [
          ('route-2', 'Zara'),
          ('route-1', 'Beans'),
          ('route-1', 'Anna'),
          ('route-2', 'Amir'),
        ];

        List<String> sequenceForDay(DateTime day, int createdMsBase) {
          // Simulate the recreation service: each order gets a fresh
          // createdAt stamped in whatever loop order, near-identical times.
          final orders = <Order>[];
          for (var i = 0; i < customers.length; i++) {
            final (route, name) = customers[i];
            orders.add(
              orderOn(
                DateTime(day.year, day.month, day.day, 9),
                route: route,
                name: name,
                // Vary createdAt ordering day-to-day to prove it is ignored.
                createdAt: DateTime(
                  day.year,
                  day.month,
                  day.day,
                  5,
                  0,
                  0,
                  createdMsBase + (customers.length - i),
                ),
              ),
            );
          }
          return sequence(orders);
        }

        final jun13 = sequenceForDay(DateTime(2025, 6, 13), 100);
        final jun14 = sequenceForDay(DateTime(2025, 6, 14), 700);
        final jun15 = sequenceForDay(DateTime(2025, 6, 15), 3);

        expect(jun13, ['Anna', 'Beans', 'Amir', 'Zara']);
        expect(jun14, jun13);
        expect(jun15, jun13);
      },
    );
  });

  group('compareOrdersByDate across days', () {
    test('newest day first by default, still route/name within a day', () {
      final orders = [
        orderOn(DateTime(2025, 6, 12, 9), route: 'route-1', name: 'Anna'),
        orderOn(DateTime(2025, 6, 13, 9), route: 'route-2', name: 'Zara'),
        orderOn(DateTime(2025, 6, 13, 9), route: 'route-1', name: 'Beans'),
      ];
      final copy = [...orders]..sort((a, b) => compareOrdersByDate(a, b));
      expect(
        copy.map((o) => '${o.orderDate.day}:${o.customerName}').toList(),
        ['13:Beans', '13:Zara', '12:Anna'],
      );
    });
  });
}
