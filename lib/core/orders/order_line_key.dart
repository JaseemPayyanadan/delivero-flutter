import '../../data/models/order.dart';

/// Stable key for merging order lines (same product + same pack label).
String orderItemMergeKey(OrderItem item) {
  final label = item.packLabel?.trim();
  if (label == null || label.isEmpty) return item.foodItemId;
  return '${item.foodItemId}|$label';
}

bool orderItemsMatchForMerge(OrderItem a, OrderItem b) {
  return orderItemMergeKey(a) == orderItemMergeKey(b);
}

/// Line key used in the create-order draft (`foodItemId` or `foodItemId|packLabel`).
String orderLineKey(String foodItemId, [String? packLabel]) {
  final label = packLabel?.trim();
  if (label == null || label.isEmpty) return foodItemId;
  return '$foodItemId|$label';
}

String foodItemIdFromLineKey(String lineKey) {
  final i = lineKey.indexOf('|');
  return i < 0 ? lineKey : lineKey.substring(0, i);
}

String? packLabelFromLineKey(String lineKey) {
  final i = lineKey.indexOf('|');
  if (i < 0) return null;
  final label = lineKey.substring(i + 1).trim();
  return label.isEmpty ? null : label;
}

String displayNameWithPackLabel(String productName, String? packLabel) {
  final label = packLabel?.trim();
  if (label == null || label.isEmpty) return productName;
  return '$productName ($label)';
}
