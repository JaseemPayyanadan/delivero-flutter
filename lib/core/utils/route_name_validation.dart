import '../../data/models/delivery_route.dart';

const int kRouteNameMaxLength = 50;

/// Validates a route name for create/edit flows.
///
/// Returns an error message when invalid, or `null` when [trimmedName] is OK.
String? validateRouteName(
  String trimmedName, {
  required List<DeliveryRoute> existingRoutes,
  String? editingRouteId,
}) {
  if (trimmedName.isEmpty) {
    return 'Enter a route name.';
  }
  if (trimmedName.length > kRouteNameMaxLength) {
    return 'Route name must be $kRouteNameMaxLength characters or fewer.';
  }

  final normalized = trimmedName.toLowerCase();
  final duplicate = existingRoutes.any((route) {
    if (editingRouteId != null && route.id == editingRouteId) return false;
    return route.name.trim().toLowerCase() == normalized;
  });
  if (duplicate) {
    return 'A route with this name already exists.';
  }

  return null;
}
