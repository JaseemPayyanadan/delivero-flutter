import 'package:delivero/data/models/order.dart';
import 'package:delivero/data/models/product_unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to quantity', () {
    const item = OrderItem(
      id: 'l1',
      foodItemId: 'f1',
      foodItemName: 'Rice',
      quantity: 2,
      unitPrice: 50,
      totalPrice: 100,
    );
    expect(item.unit, ProductUnit.quantity);
  });

  test('JSON round-trips the unit', () {
    const item = OrderItem(
      id: 'l1',
      foodItemId: 'f1',
      foodItemName: 'Rice',
      quantity: 2,
      unitPrice: 50,
      totalPrice: 100,
      unit: ProductUnit.litre,
    );
    final json = item.toJson();
    expect(json['unit'], 'litre');
    expect(OrderItem.fromJson(json).unit, ProductUnit.litre);
  });

  test('legacy JSON with no unit decodes to quantity', () {
    final item = OrderItem.fromJson({
      'id': 'l1',
      'foodItemId': 'f1',
      'foodItemName': 'Rice',
      'quantity': 2,
      'unitPrice': 50,
      'totalPrice': 100,
    });
    expect(item.unit, ProductUnit.quantity);
  });
}
