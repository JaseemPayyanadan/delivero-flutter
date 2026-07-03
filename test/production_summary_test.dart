import 'package:delivero/core/production/production_summary.dart';
import 'package:delivero/data/models/order.dart';
import 'package:delivero/data/models/product_unit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/production_test_data.dart';

void main() {
  final scopeDay = DateTime(2025, 6, 20);
  final routes = [productionTestRoute()];

  group('filterOrdersForProduction', () {
    test('excludes pre-7 AM orders from same calendar production day', () {
      final orders = [
        productionTestOrder(id: 'early', orderDate: DateTime(2025, 6, 20, 6)),
        productionTestOrder(
          id: 'after-seven',
          orderDate: DateTime(2025, 6, 20, 8),
        ),
      ];
      final filtered = filterOrdersForProduction(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
      );
      expect(filtered.map((o) => o.id).toList(), ['after-seven']);
    });

    test('keeps same-day non-cancelled orders', () {
      final orders = [
        productionTestOrder(id: 'o1'),
        productionTestOrder(id: 'o2', status: OrderStatus.cancelled),
        productionTestOrder(id: 'o3', orderDate: DateTime(2025, 6, 19)),
      ];
      final filtered = filterOrdersForProduction(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
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
          rolloverHour: 7,
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
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
      );

      expect(summary.activeOrders, 3);
      expect(summary.lines.length, 1);
      final japathi = summary.lines.first;
      expect(japathi.productName, 'Japathi');
      expect(japathi.totalUnits, 70);
      expect(japathi.orderLineCount, 4);
      expect(japathi.packBreakdown[20], 3);
      expect(japathi.packBreakdown[10], 1);
      expect(summary.totalUnits, 70);
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
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
      );

      expect(summary.lines.length, 2);
      expect(summary.totalUnits, 50);
    });

    test('separates pack labels for the same product', () {
      final orders = [
        productionTestOrder(
          id: 'o1',
          items: [
            OrderItem(
              id: 'l1',
              foodItemId: 'food-1',
              foodItemName: 'Japathi',
              quantity: 50,
              unitPrice: 10,
              totalPrice: 500,
              packLabel: 'Box 1',
            ),
            OrderItem(
              id: 'l2',
              foodItemId: 'food-1',
              foodItemName: 'Japathi',
              quantity: 50,
              unitPrice: 10,
              totalPrice: 500,
              packLabel: 'Box 2',
            ),
          ],
        ),
      ];

      final summary = buildProductionSummary(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
      );

      expect(summary.lines.length, 2);
      expect(summary.totalUnits, 100);
      expect(summary.lines.map((l) => l.productName).toSet(), {
        'Japathi (Box 1)',
        'Japathi (Box 2)',
      });
    });

    test(
      'separates items with same name and different pack labels when foodItemId is empty',
      () {
        final orders = [
          productionTestOrder(
            id: 'o1',
            items: [
              OrderItem(
                id: 'l1',
                foodItemId: '',
                foodItemName: 'Milk',
                quantity: 10,
                unitPrice: 20,
                totalPrice: 200,
                packLabel: '500ml',
              ),
              OrderItem(
                id: 'l2',
                foodItemId: '',
                foodItemName: 'Milk',
                quantity: 5,
                unitPrice: 40,
                totalPrice: 200,
                packLabel: '1L',
              ),
            ],
          ),
        ];

        final summary = buildProductionSummary(
          orders,
          ProductionSummaryScope(
            day: scopeDay,
            routes: routes,
            rolloverHour: 7,
          ),
        );

        expect(summary.lines.length, 2);
        expect(summary.lines.map((l) => l.productName).toSet(), {
          'Milk (500ml)',
          'Milk (1L)',
        });
      },
    );

    test('counts orders by type', () {
      final orders = [
        productionTestOrder(id: 'o1', orderType: OrderType.daily),
        productionTestOrder(id: 'o2', orderType: OrderType.oneTime),
      ];
      final summary = buildProductionSummary(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
      );
      expect(summary.ordersByType[OrderType.daily], 1);
      expect(summary.ordersByType[OrderType.oneTime], 1);
    });
  });

  group('production summary units', () {
    test('kg product line uses kg wording', () {
      final orders = [
        productionTestOrder(
          id: 'kg-order',
          orderDate: DateTime(2025, 6, 20, 10),
          items: const [
            OrderItem(
              id: 'l1',
              foodItemId: 'rice',
              foodItemName: 'Rice',
              quantity: 12,
              unitPrice: 50,
              totalPrice: 600,
              unit: ProductUnit.kilogram,
            ),
          ],
        ),
      ];
      final summary = buildProductionSummary(
        orders,
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
      );
      final line = summary.lines.single;
      expect(line.unit, ProductUnit.kilogram);
      expect(formatProductionLine(line), contains('12 kg total'));
    });

    test('quantity product keeps legacy units wording', () {
      final summary = buildProductionSummary(
        [productionTestOrder(orderDate: DateTime(2025, 6, 20, 10))],
        ProductionSummaryScope(day: scopeDay, routes: routes, rolloverHour: 7),
      );
      expect(
        formatProductionLine(summary.lines.single),
        contains('units total'),
      );
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
          rolloverHour: 7,
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
