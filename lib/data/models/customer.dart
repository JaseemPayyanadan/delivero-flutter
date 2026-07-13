import '../../core/utils/date_utils.dart' as app_utils;

class Customer {
  final String id;
  final String factoryId;
  final String name;
  final String? ownerName;
  final String email;
  final String phone;
  final String address;
  final String area;
  final bool isActive;
  final double? discountPercentage;

  /// Canonical [DeliveryRoute.id] for this customer's delivery route.
  final String? assignedRoute;
  final List<CustomerProduct>? products;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Customer({
    required this.id,
    required this.factoryId,
    required this.name,
    this.ownerName,
    required this.email,
    required this.phone,
    required this.address,
    required this.area,
    required this.isActive,
    this.discountPercentage,
    this.assignedRoute,
    this.products,
    required this.createdAt,
    required this.updatedAt,
  });

  Customer copyWith({
    String? name,
    String? ownerName,
    String? email,
    String? phone,
    String? address,
    String? area,
    bool? isActive,
    double? discountPercentage,
    String? assignedRoute,
    List<CustomerProduct>? products,
    DateTime? updatedAt,
  }) {
    return Customer(
      id: id,
      factoryId: factoryId,
      name: name ?? this.name,
      ownerName: ownerName ?? this.ownerName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      area: area ?? this.area,
      isActive: isActive ?? this.isActive,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      assignedRoute: assignedRoute ?? this.assignedRoute,
      products: products ?? this.products,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factoryId': factoryId,
      'name': name,
      'ownerName': ownerName,
      'email': email,
      'phone': phone,
      'address': address,
      'area': area,
      'isActive': isActive,
      'discountPercentage': discountPercentage,
      'assignedRoute': assignedRoute,
      'products': products?.map((p) => p.toJson()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      factoryId: json['factoryId'] ?? '',
      name: json['name'] ?? '',
      ownerName: json['ownerName'] as String?,
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      area: json['area'] ?? '',
      isActive: json['isActive'] ?? true,
      discountPercentage: (json['discountPercentage'] as num?)?.toDouble(),
      assignedRoute: json['assignedRoute'] as String?,
      products: (json['products'] as List<dynamic>?)
          ?.map((p) => CustomerProduct.fromJson(p as Map<String, dynamic>))
          .toList(),
      createdAt: app_utils.DateUtils.parse(json['createdAt']),
      updatedAt: app_utils.DateUtils.parse(json['updatedAt']),
    );
  }
}

class CustomerProduct {
  final String id;
  final String name;
  final int quantity;
  final double? customPrice;

  const CustomerProduct({
    required this.id,
    required this.name,
    required this.quantity,
    this.customPrice,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'customPrice': customPrice,
    };
  }

  factory CustomerProduct.fromJson(Map<String, dynamic> json) {
    return CustomerProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      quantity: json['quantity'] as int,
      customPrice: (json['customPrice'] as num?)?.toDouble(),
    );
  }
}
