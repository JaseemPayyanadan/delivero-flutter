import '../../core/utils/date_utils.dart' as app_utils;

enum OrderType { daily, oneTime }

enum PaymentStatus { paid, unpaid, partial }

enum PaymentMethod { cash, upi, card, online }

enum OrderStatus { pending, confirmed, preparing, ready, delivered, cancelled }

class OrderItem {
  final String id;
  final String foodItemId;
  final String foodItemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  const OrderItem({
    required this.id,
    required this.foodItemId,
    required this.foodItemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodItemId': foodItemId,
      'foodItemName': foodItemName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      foodItemId: json['foodItemId'] as String,
      foodItemName: json['foodItemName'] as String,
      quantity: json['quantity'] as int,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
    );
  }
}

class Order {
  final String id;
  final String factoryId;
  final OrderType orderType;
  final String customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final String customerAddress;
  final List<OrderItem> items;
  final double subtotal;
  final double discountAmount;
  final double totalAmount;
  final PaymentStatus? paymentStatus;
  final PaymentMethod? paymentMethod;
  final double? amountPaid;
  final OrderStatus status;
  final String? assignedRoute;
  final String? assignedDriver;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final DateTime? paymentTime;
  final DateTime? deliveryTime;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.factoryId,
    required this.orderType,
    required this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.customerAddress,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.totalAmount,
    this.paymentStatus,
    this.paymentMethod,
    this.amountPaid,
    required this.status,
    this.assignedRoute,
    this.assignedDriver,
    required this.orderDate,
    this.deliveryDate,
    this.paymentTime,
    this.deliveryTime,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factoryId': factoryId,
      'orderType': orderType == OrderType.oneTime ? 'one-time' : 'daily',
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'totalAmount': totalAmount,
      'paymentStatus': paymentStatus?.name,
      'paymentMethod': paymentMethod?.name,
      'amountPaid': amountPaid,
      'status': status.name,
      'assignedRoute': assignedRoute,
      'assignedDriver': assignedDriver,
      'orderDate': orderDate,
      'deliveryDate': deliveryDate,
      'paymentTime': paymentTime,
      'deliveryTime': deliveryTime,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      factoryId: json['factoryId'] ?? '',
      orderType: _parseOrderType(json['orderType']),
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerEmail: json['customerEmail'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      customerAddress: json['customerAddress'] ?? '',
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: _parsePaymentStatus(json['paymentStatus']),
      paymentMethod: _parsePaymentMethod(json['paymentMethod']),
      amountPaid: (json['amountPaid'] as num?)?.toDouble(),
      status: _parseOrderStatus(json['status']),
      assignedRoute: json['assignedRoute'] as String?,
      assignedDriver: json['assignedDriver'] as String?,
      orderDate: app_utils.DateUtils.parse(json['orderDate']),
      deliveryDate: json['deliveryDate'] != null
          ? app_utils.DateUtils.parse(json['deliveryDate'])
          : null,
      paymentTime: json['paymentTime'] != null
          ? app_utils.DateUtils.parse(json['paymentTime'])
          : null,
      deliveryTime: json['deliveryTime'] != null
          ? app_utils.DateUtils.parse(json['deliveryTime'])
          : null,
      notes: json['notes'] as String?,
      createdAt: app_utils.DateUtils.parse(json['createdAt']),
      updatedAt: app_utils.DateUtils.parse(json['updatedAt']),
    );
  }

  static OrderType _parseOrderType(dynamic value) {
    if (value == null) return OrderType.daily;
    final stringValue = value.toString().toLowerCase();
    if (stringValue == 'one-time') return OrderType.oneTime;
    return OrderType.values.firstWhere(
      (v) => v.name.toLowerCase() == stringValue,
      orElse: () => OrderType.daily,
    );
  }

  static PaymentStatus? _parsePaymentStatus(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString().toLowerCase();
    return PaymentStatus.values.firstWhere(
      (v) => v.name.toLowerCase() == stringValue,
      orElse: () => PaymentStatus.unpaid,
    );
  }

  static PaymentMethod? _parsePaymentMethod(dynamic value) {
    if (value == null) return null;
    final stringValue = value.toString().toLowerCase();
    return PaymentMethod.values.firstWhere(
      (v) => v.name.toLowerCase() == stringValue,
      orElse: () => PaymentMethod.cash,
    );
  }

  static OrderStatus _parseOrderStatus(dynamic value) {
    if (value == null) return OrderStatus.pending;
    final stringValue = value.toString().toLowerCase();
    return OrderStatus.values.firstWhere(
      (v) => v.name.toLowerCase() == stringValue,
      orElse: () => OrderStatus.pending,
    );
  }

  Order copyWith({
    String? id,
    String? factoryId,
    OrderType? orderType,
    String? customerId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    String? customerAddress,
    List<OrderItem>? items,
    double? subtotal,
    double? discountAmount,
    double? totalAmount,
    PaymentStatus? paymentStatus,
    PaymentMethod? paymentMethod,
    double? amountPaid,
    OrderStatus? status,
    String? assignedRoute,
    String? assignedDriver,
    DateTime? orderDate,
    DateTime? deliveryDate,
    DateTime? paymentTime,
    DateTime? deliveryTime,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      factoryId: factoryId ?? this.factoryId,
      orderType: orderType ?? this.orderType,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      customerAddress: customerAddress ?? this.customerAddress,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amountPaid: amountPaid ?? this.amountPaid,
      status: status ?? this.status,
      assignedRoute: assignedRoute ?? this.assignedRoute,
      assignedDriver: assignedDriver ?? this.assignedDriver,
      orderDate: orderDate ?? this.orderDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      paymentTime: paymentTime ?? this.paymentTime,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
