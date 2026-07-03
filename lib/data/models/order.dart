import 'package:flutter/foundation.dart';

import '../../core/utils/date_utils.dart' as app_utils;
import 'product_unit.dart';

enum OrderType { daily, oneTime, special }

/// When during the day this order is fulfilled (morning vs evening, etc.).
enum DeliveryRun { morning, afternoon, evening, night }

extension DeliveryRunLabels on DeliveryRun {
  String get label => switch (this) {
    DeliveryRun.morning => 'Morning',
    DeliveryRun.afternoon => 'Afternoon',
    DeliveryRun.evening => 'Evening',
    DeliveryRun.night => 'Night',
  };
}

enum PaymentStatus { paid, unpaid, partial }

enum PaymentMethod { cash, upi, card, online }

enum OrderStatus { pending, confirmed, preparing, ready, delivered, cancelled }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
    OrderStatus.pending => 'Pending',
    OrderStatus.confirmed => 'Confirmed',
    OrderStatus.preparing => 'Preparing',
    OrderStatus.ready => 'Ready',
    OrderStatus.delivered => 'Delivered',
    OrderStatus.cancelled => 'Cancelled',
  };
}

class OrderItem {
  final String id;
  final String foodItemId;
  final String foodItemName;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final ProductUnit unit;

  /// Optional pack/box label when the same product appears on multiple lines.
  final String? packLabel;

  const OrderItem({
    required this.id,
    required this.foodItemId,
    required this.foodItemName,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    this.unit = ProductUnit.quantity,
    this.packLabel,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'foodItemId': foodItemId,
      'foodItemName': foodItemName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'unit': unit.storageValue,
      if (packLabel != null && packLabel!.trim().isNotEmpty)
        'packLabel': packLabel!.trim(),
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    int readInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double readDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    String readString(dynamic value) {
      return value?.toString() ?? '';
    }

    final foodItemId = readString(
      json['foodItemId'] ?? json['itemId'] ?? json['productId'],
    );
    final foodItemName = readString(
      json['foodItemName'] ?? json['name'] ?? json['itemName'],
    );
    final quantity = readInt(json['quantity'] ?? json['qty'] ?? json['count']);
    final unitPrice = readDouble(
      json['unitPrice'] ?? json['price'] ?? json['unit_price'],
    );
    final totalPriceRaw = json['totalPrice'] ?? json['total'] ?? json['amount'];
    final totalPrice = totalPriceRaw == null
        ? unitPrice * quantity
        : readDouble(totalPriceRaw);

    final packLabelRaw =
        json['packLabel'] ?? json['pack_label'] ?? json['boxLabel'];
    final packLabel = packLabelRaw == null
        ? null
        : readString(packLabelRaw).trim();

    return OrderItem(
      id: readString(json['id'] ?? json['lineId'] ?? foodItemId),
      foodItemId: foodItemId,
      foodItemName: foodItemName,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      unit: ProductUnit.fromStorage(json['unit']),
      packLabel: packLabel == null || packLabel.isEmpty ? null : packLabel,
    );
  }
}

class Order {
  final String id;
  final String factoryId;
  final OrderType orderType;
  final DeliveryRun deliveryRun;
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

  /// Canonical [DeliveryRoute.id] for fulfillment routing.
  final String? assignedRoute;
  final String? assignedDriver;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final DateTime? paymentTime;
  final DateTime? deliveryTime;
  final String? notes;

  /// When set, this order was auto-created from the referenced delivered daily order.
  final String? recreatedFromOrderId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Order({
    required this.id,
    required this.factoryId,
    required this.orderType,
    this.deliveryRun = DeliveryRun.morning,
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
    this.recreatedFromOrderId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factoryId': factoryId,
      'orderType': switch (orderType) {
        OrderType.daily => 'daily',
        OrderType.oneTime => 'one-time',
        OrderType.special => 'special',
      },
      'deliveryRun': deliveryRun.name,
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
      if (recreatedFromOrderId != null)
        'recreatedFromOrderId': recreatedFromOrderId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    String readString(dynamic value) {
      return value?.toString() ?? '';
    }

    double readDouble(dynamic value) {
      if (value is double) return value;
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0.0;
    }

    Map<String, dynamic>? readMap(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    }

    final customerMap = readMap(json['customer']);
    final customerName = readString(json['customerName']).isNotEmpty
        ? readString(json['customerName'])
        : readString(json['customer_name']);

    final resolvedCustomerName = customerName.isNotEmpty
        ? customerName
        : readString(customerMap?['name'] ?? customerMap?['customerName']);

    return Order(
      id: readString(json['id']),
      factoryId: readString(json['factoryId'] ?? json['factory_id']),
      orderType: _parseOrderType(json['orderType']),
      deliveryRun: _parseDeliveryRun(
        json['deliveryRun'] ?? json['delivery_run'],
      ),
      customerId: readString(
        json['customerId'] ?? json['customer_id'] ?? customerMap?['id'],
      ),
      customerName: resolvedCustomerName,
      customerEmail: readString(
        json['customerEmail'] ??
            json['customer_email'] ??
            customerMap?['email'],
      ),
      customerPhone: readString(
        json['customerPhone'] ??
            json['customer_phone'] ??
            customerMap?['phone'],
      ),
      customerAddress: readString(
        json['customerAddress'] ??
            json['customer_address'] ??
            customerMap?['address'],
      ),
      items:
          (json['items'] as List<dynamic>?)
              ?.map((i) => OrderItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: readDouble(json['subtotal'] ?? json['sub_total']),
      discountAmount: readDouble(
        json['discountAmount'] ?? json['discount'] ?? json['discount_amount'],
      ),
      totalAmount: readDouble(
        json['totalAmount'] ?? json['total'] ?? json['total_amount'],
      ),
      paymentStatus: _parsePaymentStatus(json['paymentStatus']),
      paymentMethod: _parsePaymentMethod(json['paymentMethod']),
      amountPaid: (json['amountPaid'] is num)
          ? (json['amountPaid'] as num).toDouble()
          : (json['amount_paid'] is num)
          ? (json['amount_paid'] as num).toDouble()
          : null,
      status: _parseOrderStatus(json['status'] ?? json['orderStatus']),
      assignedRoute:
          readString(
            json['assignedRoute'] ?? json['routeId'] ?? json['route_id'],
          ).isEmpty
          ? null
          : readString(
              json['assignedRoute'] ?? json['routeId'] ?? json['route_id'],
            ),
      assignedDriver:
          readString(
            json['assignedDriver'] ?? json['driverId'] ?? json['driver_id'],
          ).isEmpty
          ? null
          : readString(
              json['assignedDriver'] ?? json['driverId'] ?? json['driver_id'],
            ),
      orderDate: () {
        final raw = json['orderDate'] ?? json['order_date'];
        if (raw == null) {
          debugPrint(
            '[Order] orderDate missing for id=${json['id']} — falling back to createdAt',
          );
        }
        return app_utils.DateUtils.parse(raw ?? json['createdAt']);
      }(),
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
      recreatedFromOrderId: readString(json['recreatedFromOrderId']).isEmpty
          ? null
          : readString(json['recreatedFromOrderId']),
      createdAt: app_utils.DateUtils.parse(json['createdAt']),
      updatedAt: app_utils.DateUtils.parse(json['updatedAt']),
    );
  }

  static OrderType _parseOrderType(dynamic value) {
    if (value == null) return OrderType.daily;
    final stringValue = value.toString().toLowerCase();
    if (stringValue == 'one-time') return OrderType.oneTime;
    if (stringValue == 'special') return OrderType.special;
    return OrderType.values.firstWhere(
      (v) => v.name.toLowerCase() == stringValue,
      orElse: () {
        debugPrint('[Order] Unknown orderType "$value" — defaulting to daily');
        return OrderType.daily;
      },
    );
  }

  static DeliveryRun _parseDeliveryRun(dynamic value) {
    if (value == null) return DeliveryRun.morning;
    final stringValue = value.toString().toLowerCase();
    return DeliveryRun.values.firstWhere(
      (v) => v.name.toLowerCase() == stringValue,
      orElse: () => DeliveryRun.morning,
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
    DeliveryRun? deliveryRun,
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
    String? recreatedFromOrderId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id ?? this.id,
      factoryId: factoryId ?? this.factoryId,
      orderType: orderType ?? this.orderType,
      deliveryRun: deliveryRun ?? this.deliveryRun,
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
      recreatedFromOrderId: recreatedFromOrderId ?? this.recreatedFromOrderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
