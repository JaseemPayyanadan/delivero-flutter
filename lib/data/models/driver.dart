import '../../core/utils/date_utils.dart' as app_utils;

enum VehicleType { bike, scooter, auto, van }

/// Lifecycle of a driver record:
/// - [pending]: created by an owner but not yet linked to a verified phone login.
/// - [active]: a Firebase Auth user (phone OTP) has been linked via [Driver.userId].
enum DriverStatus { pending, active }

class Driver {
  final String id;
  final String factoryId;
  final String name;
  final String phone;
  final VehicleType vehicleType;
  final String? licenseNumber;
  final bool isActive;
  final String? currentRoute;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Firebase Auth UID once the driver signs in with this phone for the first time.
  final String? userId;
  final DriverStatus status;

  const Driver({
    required this.id,
    required this.factoryId,
    required this.name,
    required this.phone,
    required this.vehicleType,
    this.licenseNumber,
    required this.isActive,
    this.currentRoute,
    required this.createdAt,
    required this.updatedAt,
    this.userId,
    this.status = DriverStatus.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'factoryId': factoryId,
      'name': name,
      'phone': phone,
      'vehicleType':
          vehicleType.name[0].toUpperCase() + vehicleType.name.substring(1),
      'licenseNumber': licenseNumber,
      'isActive': isActive,
      'currentRoute': currentRoute,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'userId': userId,
      'status': status.name,
    };
  }

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as String,
      factoryId: json['factoryId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      vehicleType: _parseVehicleType(json['vehicleType']),
      licenseNumber: json['licenseNumber'] as String?,
      isActive: json['isActive'] ?? true,
      currentRoute: json['currentRoute'] as String?,
      createdAt: app_utils.DateUtils.parse(json['createdAt']),
      updatedAt: app_utils.DateUtils.parse(json['updatedAt']),
      userId: json['userId'] as String?,
      status: _parseStatus(json['status']),
    );
  }

  Driver copyWith({
    String? id,
    String? factoryId,
    String? name,
    String? phone,
    VehicleType? vehicleType,
    String? licenseNumber,
    bool? isActive,
    String? currentRoute,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    DriverStatus? status,
  }) {
    return Driver(
      id: id ?? this.id,
      factoryId: factoryId ?? this.factoryId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehicleType: vehicleType ?? this.vehicleType,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      isActive: isActive ?? this.isActive,
      currentRoute: currentRoute ?? this.currentRoute,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userId: userId ?? this.userId,
      status: status ?? this.status,
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

  static DriverStatus _parseStatus(dynamic value) {
    if (value == null) return DriverStatus.pending;
    final s = value.toString().toLowerCase();
    return DriverStatus.values.firstWhere(
      (v) => v.name == s,
      orElse: () => DriverStatus.pending,
    );
  }
}
