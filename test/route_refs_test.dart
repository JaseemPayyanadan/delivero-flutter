import 'package:delivero/core/utils/route_refs.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/route_test_data.dart';

void main() {
  group('RouteRefs.routeForRef', () {
    test('returns route when ref is canonical id', () {
      final routes = sampleRoutes;
      expect(RouteRefs.routeForRef('route-1', routes)?.name, 'North Loop');
    });

    test('returns route when ref is legacy name', () {
      final routes = sampleRoutes;
      expect(RouteRefs.routeForRef('North Loop', routes)?.id, 'route-1');
    });

    test('trims whitespace before lookup', () {
      final routes = sampleRoutes;
      expect(RouteRefs.routeForRef('  route-1  ', routes)?.id, 'route-1');
    });

    test('returns null for empty or unknown ref', () {
      final routes = sampleRoutes;
      expect(RouteRefs.routeForRef(null, routes), isNull);
      expect(RouteRefs.routeForRef('', routes), isNull);
      expect(RouteRefs.routeForRef('Unknown Route', routes), isNull);
    });
  });

  group('RouteRefs.routeIdForRef', () {
    test('returns id for id or legacy name', () {
      final routes = sampleRoutes;
      expect(RouteRefs.routeIdForRef('route-2', routes), 'route-2');
      expect(RouteRefs.routeIdForRef('South Bay', routes), 'route-2');
    });
  });

  group('RouteRefs.routeLabelForRef', () {
    test('returns route name when resolved', () {
      final routes = sampleRoutes;
      expect(RouteRefs.routeLabelForRef('route-1', routes), 'North Loop');
      expect(RouteRefs.routeLabelForRef('North Loop', routes), 'North Loop');
    });

    test('returns loading label when routes not loaded yet', () {
      expect(
        RouteRefs.routeLabelForRef(
          'route-1',
          const [],
          routesLoaded: false,
        ),
        'Loading route…',
      );
    });

    test('returns raw ref or fallback when unresolved', () {
      final routes = sampleRoutes;
      expect(
        RouteRefs.routeLabelForRef('Orphan Ref', routes),
        'Orphan Ref',
      );
      expect(RouteRefs.routeLabelForRef(null, routes), 'No route');
    });
  });

  group('RouteRefs.matchesRoute', () {
    test('matches id or legacy name', () {
      final route = testRoute();
      expect(RouteRefs.matchesRoute('route-1', route), isTrue);
      expect(RouteRefs.matchesRoute('North Loop', route), isTrue);
      expect(RouteRefs.matchesRoute('route-2', route), isFalse);
    });
  });

  group('RouteRefs.matchesRouteId', () {
    test('matches only canonical id', () {
      expect(RouteRefs.matchesRouteId('route-1', 'route-1'), isTrue);
      expect(RouteRefs.matchesRouteId('North Loop', 'route-1'), isFalse);
      expect(RouteRefs.matchesRouteId('', 'route-1'), isFalse);
    });
  });

  group('RouteRefs.isLegacyOrUnknownRef', () {
    test('is false for canonical id', () {
      expect(RouteRefs.isLegacyOrUnknownRef('route-1', sampleRoutes), isFalse);
    });

    test('is true for legacy name', () {
      expect(
        RouteRefs.isLegacyOrUnknownRef('North Loop', sampleRoutes),
        isTrue,
      );
    });

    test('is true for unknown non-empty ref', () {
      expect(
        RouteRefs.isLegacyOrUnknownRef('Deleted Route', sampleRoutes),
        isTrue,
      );
    });

    test('is false for null or empty ref', () {
      expect(RouteRefs.isLegacyOrUnknownRef(null, sampleRoutes), isFalse);
      expect(RouteRefs.isLegacyOrUnknownRef('', sampleRoutes), isFalse);
    });
  });
}
