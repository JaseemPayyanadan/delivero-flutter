import 'package:delivero/data/models/food_item.dart';
import 'package:delivero/data/models/product_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2025, 1, 1);

  FoodItem make(ProductUnit unit) => FoodItem(
        id: 'f1',
        factoryId: 'FAC',
        name: 'Rice',
        price: 50,
        unit: unit,
        createdAt: now,
        updatedAt: now,
      );

  test('defaults to quantity', () {
    final item = FoodItem(
      id: 'f1',
      factoryId: 'FAC',
      name: 'Rice',
      price: 50,
      createdAt: now,
      updatedAt: now,
    );
    expect(item.unit, ProductUnit.quantity);
  });

  test('JSON round-trips the unit', () {
    final json = make(ProductUnit.kilogram).toJson();
    expect(json['unit'], 'kg');
    expect(FoodItem.fromJson(json).unit, ProductUnit.kilogram);
  });

  test('legacy JSON with no unit decodes to quantity', () {
    final item = FoodItem.fromJson({
      'id': 'f1',
      'factoryId': 'FAC',
      'name': 'Rice',
      'price': 50,
      'createdAt': now,
      'updatedAt': now,
    });
    expect(item.unit, ProductUnit.quantity);
  });
}
