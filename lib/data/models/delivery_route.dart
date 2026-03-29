import '../../core/utils/date_utils.dart' as app_utils;

class DeliveryRoute {
  final String id;
  final String factoryId;
  final String name;
  final String description;
  final String area;
  final String? assignedDriver;
  final bool isActive;
  final int estimatedDeliveryTime; // in minutes
  final int maxOrders;
  final int currentOrders;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeliveryRoute({
    required this.id,
    required this.factoryId,
    required this.name,
    required this.description,
    required this.area,
    this.assignedDriver,
    required this.isActive,
    required this.estimatedDeliveryTime,
    required this.maxOrders,
    required this.currentOrders,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factoryId': factoryId,
      'name': name,
      'description': description,
      'area': area,
      'assignedDriver': assignedDriver,
      'isActive': isActive,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'maxOrders': maxOrders,
      'currentOrders': currentOrders,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    return DeliveryRoute(
      id: json['id'] as String,
      factoryId: json['factoryId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      area: json['area'] ?? '',
      assignedDriver: json['assignedDriver'] as String?,
      isActive: json['isActive'] ?? true,
      estimatedDeliveryTime: json['estimatedDeliveryTime'] ?? 0,
      maxOrders: json['maxOrders'] ?? 0,
      currentOrders: json['currentOrders'] ?? 0,
      createdAt: app_utils.DateUtils.parse(json['createdAt']),
      updatedAt: app_utils.DateUtils.parse(json['updatedAt']),
    );
  }
}
