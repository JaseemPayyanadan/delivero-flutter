import '../../data/models/order.dart';

/// Sort orders by [orderDate], then within the same day by a stable
/// route → customer-name sequence so every day renders in an identical order.
/// [createdAt] is only a last-resort fallback. Default: newest day first.
///
/// The within-day keys (route, name) are always ascending regardless of
/// [newestFirst] — that flag only controls day ordering. Daily orders are
/// recreated each morning with fresh [createdAt] timestamps and new ids, so
/// tie-breaking on those would shuffle the list day to day; route+name stay
/// constant for a customer and keep the sequence steady.
int compareOrdersByDate(Order a, Order b, {bool newestFirst = true}) {
  final byOrderDate = a.orderDate.compareTo(b.orderDate);
  if (byOrderDate != 0) return newestFirst ? -byOrderDate : byOrderDate;

  final byRoute = _compareRoute(a.assignedRoute, b.assignedRoute);
  if (byRoute != 0) return byRoute;

  final byName = a.customerName.toLowerCase().compareTo(
    b.customerName.toLowerCase(),
  );
  if (byName != 0) return byName;

  final byCreated = a.createdAt.compareTo(b.createdAt);
  return newestFirst ? -byCreated : byCreated;
}

/// Ascending route order, with unassigned (null/empty) routes sorted last.
int _compareRoute(String? a, String? b) {
  final na = (a == null || a.isEmpty);
  final nb = (b == null || b.isEmpty);
  if (na && nb) return 0;
  if (na) return 1;
  if (nb) return -1;
  return a.toLowerCase().compareTo(b.toLowerCase());
}

void sortOrdersByDate(List<Order> orders, {bool newestFirst = true}) {
  orders.sort((a, b) => compareOrdersByDate(a, b, newestFirst: newestFirst));
}
