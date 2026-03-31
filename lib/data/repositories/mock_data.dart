import '../models/delivery_route.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/food_item.dart';
import '../models/driver.dart';

final mockFoodItems = [
  FoodItem(
    id: 'f1',
    factoryId: 'FAC_00001',
    name: 'Standard Meal',
    price: 120.0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  FoodItem(
    id: 'f2',
    factoryId: 'FAC_00001',
    name: 'Premium Meal',
    price: 180.0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  FoodItem(
    id: 'f3',
    factoryId: 'FAC_00001',
    name: 'Snack Box',
    price: 80.0,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

final mockDrivers = [
  Driver(
    id: 'd1',
    factoryId: 'FAC_00001',
    name: 'Mike Wilson',
    email: 'delivery1@fooddist.com',
    phone: '+1-555-0301',
    vehicleType: VehicleType.bike,
    isActive: true,
    currentRoute: 'r1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Driver(
    id: 'd2',
    factoryId: 'FAC_00001',
    name: 'Sarah Brown',
    email: 'delivery2@fooddist.com',
    phone: '+1-555-0302',
    vehicleType: VehicleType.scooter,
    isActive: true,
    currentRoute: 'r2',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

final mockRoutes = [
  DeliveryRoute(
    id: 'r1',
    factoryId: 'FAC_00001',
    name: 'Downtown Route',
    description: 'Main business district',
    area: 'Central',
    assignedDriver: 'd1',
    isActive: true,
    estimatedDeliveryTime: 45,
    maxOrders: 20,
    currentOrders: 5,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  DeliveryRoute(
    id: 'r2',
    factoryId: 'FAC_00001',
    name: 'Suburb Route',
    description: 'Residential area',
    area: 'North',
    assignedDriver: 'd2',
    isActive: true,
    estimatedDeliveryTime: 60,
    maxOrders: 15,
    currentOrders: 3,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

final mockCustomers = [
  Customer(
    id: 'c1',
    factoryId: 'FAC_00001',
    name: 'Grand Hotel',
    ownerName: 'John Smith',
    email: 'contact@grandhotel.com',
    phone: '+1-555-1001',
    address: '101 Hotel St',
    area: 'Central',
    isActive: true,
    assignedRoute: 'r1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Customer(
    id: 'c2',
    factoryId: 'FAC_00001',
    name: 'City Cafe',
    ownerName: 'Alice Wong',
    email: 'info@citycafe.com',
    phone: '+1-555-1002',
    address: '202 Cafe Ave',
    area: 'Central',
    isActive: true,
    assignedRoute: 'r1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];

final mockOrders = [
  Order(
    id: 'o1',
    factoryId: 'FAC_00001',
    orderType: OrderType.daily,
    customerId: 'c1',
    customerName: 'Grand Hotel',
    customerEmail: 'contact@grandhotel.com',
    customerPhone: '+1-555-1001',
    customerAddress: '101 Hotel St',
    items: [
      OrderItem(
        id: 'oi1',
        foodItemId: 'f1',
        foodItemName: 'Standard Meal',
        quantity: 10,
        unitPrice: 120.0,
        totalPrice: 1200.0,
      ),
    ],
    subtotal: 1200.0,
    discountAmount: 0.0,
    totalAmount: 1200.0,
    status: OrderStatus.delivered,
    orderDate: DateTime.now(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
  Order(
    id: 'o2',
    factoryId: 'FAC_00001',
    orderType: OrderType.oneTime,
    customerId: 'c2',
    customerName: 'City Cafe',
    customerEmail: 'info@citycafe.com',
    customerPhone: '+1-555-1002',
    customerAddress: '202 Cafe Ave',
    items: [
      OrderItem(
        id: 'oi2',
        foodItemId: 'f2',
        foodItemName: 'Premium Meal',
        quantity: 5,
        unitPrice: 180.0,
        totalPrice: 900.0,
      ),
    ],
    subtotal: 900.0,
    discountAmount: 0.0,
    totalAmount: 900.0,
    status: OrderStatus.pending,
    orderDate: DateTime.now(),
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  ),
];
