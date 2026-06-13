import 'package:delivero/core/utils/route_name_validation.dart';
import 'package:delivero/data/models/delivery_route.dart';
import 'package:flutter_test/flutter_test.dart';

DeliveryRoute _route({required String id, required String name}) {
  return DeliveryRoute(
    id: id,
    factoryId: 'fac-1',
    name: name,
    area: 'Central',
    description: '',
    isActive: true,
    estimatedDeliveryTime: 30,
    maxOrders: 10,
    currentOrders: 0,
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
}

void main() {
  group('validateRouteName', () {
    final routes = [
      _route(id: 'r1', name: 'North Loop'),
      _route(id: 'r2', name: 'South Bay'),
    ];

    test('rejects empty names', () {
      expect(
        validateRouteName('', existingRoutes: routes),
        'Enter a route name.',
      );
    });

    test('rejects names over max length', () {
      expect(
        validateRouteName('a' * (kRouteNameMaxLength + 1), existingRoutes: routes),
        'Route name must be $kRouteNameMaxLength characters or fewer.',
      );
    });

    test('rejects duplicate names case-insensitively', () {
      expect(
        validateRouteName('north loop', existingRoutes: routes),
        'A route with this name already exists.',
      );
    });

    test('allows same name when editing the same route', () {
      expect(
        validateRouteName(
          'North Loop',
          existingRoutes: routes,
          editingRouteId: 'r1',
        ),
        isNull,
      );
    });

    test('accepts unique trimmed names', () {
      expect(
        validateRouteName('  East Side  ', existingRoutes: routes),
        isNull,
      );
    });
  });
}
