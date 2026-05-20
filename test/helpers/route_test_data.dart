import 'package:delivero/data/models/customer.dart';
import 'package:delivero/data/models/delivery_route.dart';
import 'package:delivero/data/models/order.dart';

final _fixedTime = DateTime(2025, 6, 1, 12);

DeliveryRoute testRoute({
  String id = 'route-1',
  String name = 'North Loop',
  String area = 'North',
}) {
  return DeliveryRoute(
    id: id,
    factoryId: 'FAC_001',
    name: name,
    description: '',
    area: area,
    isActive: true,
    estimatedDeliveryTime: 30,
    maxOrders: 10,
    currentOrders: 0,
    createdAt: _fixedTime,
    updatedAt: _fixedTime,
  );
}

Customer testCustomer({
  String id = 'cust-1',
  String? assignedRoute,
}) {
  return Customer(
    id: id,
    factoryId: 'FAC_001',
    name: 'Test Cafe',
    email: '',
    phone: '9999999999',
    address: '123 Main St',
    area: 'North',
    isActive: true,
    assignedRoute: assignedRoute,
    createdAt: _fixedTime,
    updatedAt: _fixedTime,
  );
}

Order testOrder({
  String id = 'order-1',
  String? assignedRoute,
}) {
  return Order(
    id: id,
    factoryId: 'FAC_001',
    orderType: OrderType.daily,
    customerId: 'cust-1',
    customerName: 'Test Cafe',
    customerEmail: '',
    customerPhone: '9999999999',
    customerAddress: '123 Main St',
    items: const [],
    subtotal: 100,
    discountAmount: 0,
    totalAmount: 100,
    status: OrderStatus.pending,
    assignedRoute: assignedRoute,
    orderDate: _fixedTime,
    createdAt: _fixedTime,
    updatedAt: _fixedTime,
  );
}

List<DeliveryRoute> get sampleRoutes => [
      testRoute(),
      testRoute(id: 'route-2', name: 'South Bay', area: 'South'),
    ];
