import 'package:delivero/core/production/production_summary.dart';
import 'package:delivero/data/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/production_test_data.dart';

void main() {
  final scopeDay = DateTime(2025, 6, 20);
  final routes = [productionTestRoute()];

  group('filterOrdersForProduction', () {
    test('keeps same-day non-cancelled orders', () {
      final orders = [
        productionTestOrder(id: 'o1'),
        productionTestOrder(
          id: 'o2',
          status: OrderStatus.cancelled,
        ),
        productionTestOrder(
          id: 'o3',
          orderDate: DateTime(2025, 6, 19),
        ),
      ];
      final filtered = filterOrdersForProduction(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes),
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, 'o1');
    });

    test('filters by route id', () {
      final orders = [
        productionTestOrder(id: 'o1', assignedRoute: 'route-1'),
        productionTestOrder(id: 'o2', assignedRoute: 'route-2'),
      ];
      final filtered = filterOrdersForProduction(
        orders,
        ProductionSummaryScope(
          day: scopeDay,
          routeId: 'route-1',
          routes: routes,
        ),
      );
      expect(filtered.length, 1);
      expect(filtered.first.id, 'o1');
    });
  });

  group('buildProductionSummary', () {
    test('aggregates total units and pack breakdown', () {
      final orders = [
        productionTestOrder(id: 'o1'),
        productionTestOrder(
          id: 'o2',
          items: [
            OrderItem(
              id: 'l1',
              foodItemId: 'food-1',
              foodItemName: 'Japathi',
              quantity: 20,
              unitPrice: 10,
              totalPrice: 200,
            ),
            OrderItem(
              id: 'l2',
              foodItemId: 'food-1',
              foodItemName: 'Japathi',
              quantity: 20,
              unitPrice: 10,
              totalPrice: 200,
            ),
          ],
        ),
        productionTestOrder(
          id: 'o3',
          items: [
            OrderItem(
              id: 'l3',
              foodItemId: 'food-1',
              foodItemName: 'Japathi',
              quantity: 10,
              unitPrice: 10,
              totalPrice: 100,
            ),
          ],
        ),
      ];

      final summary = buildProductionSummary(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes),
      );

      expect(summary.activeOrders, 3);
      expect(summary.lines.length, 1);
      final japathi = summary.lines.first;
      expect(japathi.productName, 'Japathi');
      expect(japathi.totalUnits, 50);
      expect(japathi.orderLineCount, 4);
      expect(japathi.packBreakdown[20], 3);
      expect(japathi.packBreakdown[10], 1);
      expect(summary.totalUnits, 50);
    });

    test('groups multiple products', () {
      final orders = [
        productionTestOrder(
          id: 'o1',
          items: [
            OrderItem(
              id: 'l1',
              foodItemId: 'food-1',
              foodItemName: 'Japathi',
              quantity: 20,
              unitPrice: 10,
              totalPrice: 200,
            ),
            OrderItem(
              id: 'l2',
              foodItemId: 'food-2',
              foodItemName: 'Idli',
              quantity: 30,
              unitPrice: 5,
              totalPrice: 150,
            ),
          ],
        ),
      ];

      final summary = buildProductionSummary(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes),
      );

      expect(summary.lines.length, 2);
      expect(summary.totalUnits, 50);
    });

    test('counts orders by type', () {
      final orders = [
        productionTestOrder(id: 'o1', orderType: OrderType.daily),
        productionTestOrder(id: 'o2', orderType: OrderType.oneTime),
      ];
      final summary = buildProductionSummary(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes),
      );
      expect(summary.ordersByType[OrderType.daily], 1);
      expect(summary.ordersByType[OrderType.oneTime], 1);
    });
  });

  group('formatProductionSummaryText', () {
    test('includes totals and pack breakdown', () {
      final summary = buildProductionSummary(
        [
          productionTestOrder(id: 'o1'),
          productionTestOrder(
            id: 'o2',
            items: [
              OrderItem(
                id: 'l1',
                foodItemId: 'food-1',
                foodItemName: 'Japathi',
                quantity: 20,
                unitPrice: 10,
                totalPrice: 200,
              ),
            ],
          ),
        ],
        ProductionSummaryScope(
          day: scopeDay,
          routes: routes,
          routeLabel: 'North Loop',
        ),
      );

      final text = formatProductionSummaryText(summary);
      expect(text, contains('Production list'));
      expect(text, contains('Route: North Loop'));
      expect(text, contains('JAPATHI — 40 units total'));
      expect(text, contains('2 × 20 units'));
    });
  });
}
