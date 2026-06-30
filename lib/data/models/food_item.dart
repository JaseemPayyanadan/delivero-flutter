import '../../core/utils/date_utils.dart' as app_utils;
import 'product_unit.dart';

class FoodItem {
  final String id;
  final String factoryId;
  final String name;
  final double price;
  final ProductUnit unit;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FoodItem({
    required this.id,
    required this.factoryId,
    required this.name,
    required this.price,
    this.unit = ProductUnit.quantity,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factoryId': factoryId,
      'name': name,
      'price': price,
      'unit': unit.storageValue,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] as String,
      factoryId: json['factoryId'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      unit: ProductUnit.fromStorage(json['unit']),
      createdAt: app_utils.DateUtils.parse(json['createdAt']),
      updatedAt: app_utils.DateUtils.parse(json['updatedAt']),
    );
  }
}
