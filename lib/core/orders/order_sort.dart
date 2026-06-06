import '../../data/models/order.dart';

/// Sort orders by [orderDate] then [createdAt]. Default: newest first.
int compareOrdersByDate(Order a, Order b, {bool newestFirst = true}) {
  final byOrderDate = a.orderDate.compareTo(b.orderDate);
  if (byOrderDate != 0) return newestFirst ? -byOrderDate : byOrderDate;
  final byCreated = a.createdAt.compareTo(b.createdAt);
  return newestFirst ? -byCreated : byCreated;
}

void sortOrdersByDate(List<Order> orders, {bool newestFirst = true}) {
  orders.sort((a, b) => compareOrdersByDate(a, b, newestFirst: newestFirst));
}
