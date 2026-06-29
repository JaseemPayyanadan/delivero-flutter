import 'package:delivero/app/reports_provider.dart';
import 'package:delivero/data/models/order.dart';
import 'package:delivero/data/models/product_unit.dart';
import 'package:flutter_test/flutter_test.dart';

Order _order(List<OrderItem> items) => Order(
      id: 'o1',
      factoryId: 'FAC',
      orderType: OrderType.oneTime,
      deliveryRun: DeliveryRun.morning,
      customerId: 'c1',
      customerName: 'Test',
      customerEmail: '',
      customerPhone: '',
      customerAddress: '',
      items: items,
      subtotal: 0,
      discountAmount: 0,
      totalAmount: 0,
      status: OrderStatus.delivered,
      paymentStatus: PaymentStatus.paid,
      orderDate: DateTime(2025, 6, 20),
      createdAt: DateTime(2025, 6, 20),
      updatedAt: DateTime(2025, 6, 20),
    );

OrderItem _item(String name, int qty, ProductUnit unit) => OrderItem(
      id: name,
      foodItemId: name,
      foodItemName: name,
      quantity: qty,
      unitPrice: 10,
      totalPrice: (10 * qty).toDouble(),
      unit: unit,
    );

void main() {
  test('ProductSalesData carries the product unit', () {
    final data = computeReports([
      _order([_item('Rice', 2, ProductUnit.kilogram)]),
    ]);
    expect(data.productSales['Rice']!.unit, ProductUnit.kilogram);
  });

  test('merged lines keep the first-seen unit and sum quantity', () {
    final data = computeReports([
      _order([_item('Rice', 2, ProductUnit.kilogram)]),
      _order([_item('Rice', 3, ProductUnit.kilogram)]),
    ]);
    final rice = data.productSales['Rice']!;
    expect(rice.quantity, 5);
    expect(rice.unit, ProductUnit.kilogram);
  });
}
