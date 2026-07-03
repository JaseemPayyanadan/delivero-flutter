import 'package:delivero/data/models/delivery_route.dart';
import 'package:delivero/data/models/order.dart';

final _fixedTime = DateTime(2025, 6, 20, 10);

DeliveryRoute productionTestRoute({
  String id = 'route-1',
  String name = 'North Loop',
}) {
  return DeliveryRoute(
    id: id,
    factoryId: 'FAC_001',
    name: name,
    description: '',
    area: 'North',
    isActive: true,
    estimatedDeliveryTime: 30,
    maxOrders: 10,
    currentOrders: 0,
    createdAt: _fixedTime,
    updatedAt: _fixedTime,
  );
}

Order productionTestOrder({
  String id = 'order-1',
  String? assignedRoute = 'route-1',
  OrderStatus status = OrderStatus.pending,
  OrderType orderType = OrderType.daily,
  DeliveryRun deliveryRun = DeliveryRun.morning,
  DateTime? orderDate,
  List<OrderItem>? items,
}) {
  final date = orderDate ?? _fixedTime;
  return Order(
    id: id,
    factoryId: 'FAC_001',
    orderType: orderType,
    deliveryRun: deliveryRun,
    customerId: 'cust-1',
    customerName: 'Test Cafe',
    customerEmail: '',
    customerPhone: '9999999999',
    customerAddress: '123 Main St',
    items:
        items ??
        [
          OrderItem(
            id: 'line-1',
            foodItemId: 'food-1',
            foodItemName: 'Japathi',
            quantity: 20,
            unitPrice: 10,
            totalPrice: 200,
          ),
        ],
    subtotal: 200,
    discountAmount: 0,
    totalAmount: 200,
    status: status,
    assignedRoute: assignedRoute,
    orderDate: date,
    createdAt: date,
    updatedAt: date,
  );
}
