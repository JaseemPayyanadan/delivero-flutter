import 'package:delivero/core/services/route_ref_migration.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/route_test_data.dart';

void main() {
  setUp(RouteRefMigration.resetSessionState);

  group('RouteRefMigration.needsSync', () {
    test('returns false when routes list is empty', () {
      expect(
        RouteRefMigration.needsSync(
          routes: const [],
          customers: [testCustomer(assignedRoute: 'North Loop')],
          orders: const [],
        ),
        isFalse,
      );
    });

    test('returns false when all refs are canonical ids', () {
      expect(
        RouteRefMigration.needsSync(
          routes: sampleRoutes,
          customers: [testCustomer(assignedRoute: 'route-1')],
          orders: [testOrder(assignedRoute: 'route-2')],
        ),
        isFalse,
      );
    });

    test('returns true when customer stores legacy route name', () {
      expect(
        RouteRefMigration.needsSync(
          routes: sampleRoutes,
          customers: [testCustomer(assignedRoute: 'North Loop')],
          orders: const [],
        ),
        isTrue,
      );
    });

    test('returns true when order stores legacy route name', () {
      expect(
        RouteRefMigration.needsSync(
          routes: sampleRoutes,
          customers: const [],
          orders: [testOrder(assignedRoute: 'South Bay')],
        ),
        isTrue,
      );
    });

    test('returns false when assignedRoute is null or empty', () {
      expect(
        RouteRefMigration.needsSync(
          routes: sampleRoutes,
          customers: [testCustomer()],
          orders: [testOrder()],
        ),
        isFalse,
      );
    });
  });

  group('RouteRefMigration.planMigrationTargets', () {
    test('plans customer and order updates for legacy names', () {
      final targets = RouteRefMigration.planMigrationTargets(
        routes: sampleRoutes,
        customers: [
          testCustomer(id: 'cust-1', assignedRoute: 'North Loop'),
          testCustomer(id: 'cust-2', assignedRoute: 'route-2'),
        ],
        orders: [
          testOrder(id: 'order-1', assignedRoute: 'South Bay'),
          testOrder(id: 'order-2', assignedRoute: 'route-1'),
        ],
      );

      expect(targets, [
        const RouteRefMigrationTarget(
          collection: 'customers',
          id: 'cust-1',
          routeId: 'route-1',
        ),
        const RouteRefMigrationTarget(
          collection: 'orders',
          id: 'order-1',
          routeId: 'route-2',
        ),
      ]);
    });

    test('skips records with unknown route refs', () {
      final targets = RouteRefMigration.planMigrationTargets(
        routes: sampleRoutes,
        customers: [testCustomer(assignedRoute: 'Deleted Route')],
        orders: [testOrder(assignedRoute: 'Missing')],
      );

      expect(targets, isEmpty);
    });

    test('skips records already using canonical ids', () {
      final targets = RouteRefMigration.planMigrationTargets(
        routes: sampleRoutes,
        customers: [testCustomer(assignedRoute: 'route-1')],
        orders: [testOrder(assignedRoute: 'route-2')],
      );

      expect(targets, isEmpty);
    });
  });
}
