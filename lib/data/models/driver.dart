import '../../core/utils/date_utils.dart' as app_utils;

enum VehicleType { bike, scooter, auto, van }

class Driver {
  final String id;
  final String factoryId;
  final String name;
  final String? email;
  final String phone;
  final VehicleType vehicleType;
  final String? licenseNumber;
  final bool isActive;
  final String? currentRoute;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Driver({
    required this.id,
    required this.factoryId,
    required this.name,
    this.email,
    required this.phone,
    required this.vehicleType,
    this.licenseNumber,
    required this.isActive,
    this.currentRoute,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factoryId': factoryId,
      'name': name,
      'email': email,
      'phone': phone,
      'vehicleType':
          vehicleType.name[0].toUpperCase() + vehicleType.name.substring(1),
      'licenseNumber': licenseNumber,
      'isActive': isActive,
      'currentRoute': currentRoute,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      factoryId: json['factoryId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] as String?,
      phone: json['phone'] ?? '',
      vehicleType: _parseVehicleType(json['vehicleType']),
      licenseNumber: json['licenseNumber'] as String?,
      isActive: json['isActive'] ?? true,
      currentRoute: json['currentRoute'] as String?,
      createdAt: app_utils.DateUtils.parse(json['createdAt']),
      updatedAt: app_utils.DateUtils.parse(json['updatedAt']),
    );
  }

  static VehicleType _parseVehicleType(dynamic value) {
    if (value == null) return VehicleType.bike;
    final stringValue = value.toString().toLowerCase();
    return VehicleType.values.firstWhere(
      (v) => v.name.toLowerCase() == stringValue,
      orElse: () => VehicleType.bike,
    );
  }
}
