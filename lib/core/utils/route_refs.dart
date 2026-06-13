import 'package:collection/collection.dart';

import '../../data/models/delivery_route.dart';

/// Canonical helpers for route foreign keys ([Customer.assignedRoute],
/// [Order.assignedRoute], [Driver.currentRoute]).
///
/// **Persist route ids only.** Use [routeLabelForRef] (or [routeForRef]) for UI.
abstract final class RouteRefs {
  RouteRefs._();

  static DeliveryRoute? routeForRef(
    String? ref,
    List<DeliveryRoute> routes,
  ) {
    final key = ref?.trim();
    if (key == null || key.isEmpty) return null;
    return routes.firstWhereOrNull(
      (r) => r.id == key || r.name.toLowerCase() == key.toLowerCase(),
    );
  }

  /// Resolves a stored ref (id or legacy name) to the canonical route id.
  static String? routeIdForRef(String? ref, List<DeliveryRoute> routes) {
    return routeForRef(ref, routes)?.id;
  }

  static String routeLabelForRef(
    String? ref,
    List<DeliveryRoute> routes, {
    String fallback = 'No route',
    String loadingLabel = 'Loading route…',
    bool routesLoaded = true,
  }) {
    if (!routesLoaded && routes.isEmpty) return loadingLabel;
    final route = routeForRef(ref, routes);
    if (route != null) return route.name;
    final key = ref?.trim();
    if (key != null && key.isNotEmpty) return key;
    return fallback;
  }

  static bool matchesRoute(String? ref, DeliveryRoute route) {
    final key = ref?.trim();
    if (key == null || key.isEmpty) return false;
    return key == route.id || key.toLowerCase() == route.name.toLowerCase();
  }

  static bool matchesRouteId(String? ref, String routeId) {
    final key = ref?.trim();
    final id = routeId.trim();
    if (key == null || key.isEmpty || id.isEmpty) return false;
    return key == id;
  }

  /// True when [ref] is non-empty but does not resolve to a known route id.
  static bool isLegacyOrUnknownRef(String? ref, List<DeliveryRoute> routes) {
    final key = ref?.trim();
    if (key == null || key.isEmpty) return false;
    final id = routeIdForRef(key, routes);
    return id == null || id != key;
  }
}
