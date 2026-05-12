enum UserRole { owner, delivery }

class User {
  final String id;
  final String phone;
  final String name;
  final UserRole role;
  final String? address;
  final String? avatar;
  final String? factoryId;
  final String? linkedEntityId;
  final bool hasFinishedOnboarding;

  const User({
    required this.id,
    required this.phone,
    required this.name,
    required this.role,
    this.address,
    this.avatar,
    this.factoryId,
    this.linkedEntityId,
    this.hasFinishedOnboarding = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'role': role.name,
      'address': address,
      'avatar': avatar,
      'factoryId': factoryId,
      'linkedEntityId': linkedEntityId,
      'hasFinishedOnboarding': hasFinishedOnboarding,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: (json['phone'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      role: UserRole.values.byName((json['role'] as String?) ?? 'owner'),
      address: json['address'] as String?,
      avatar: json['avatar'] as String?,
      factoryId: json['factoryId'] as String?,
      linkedEntityId: json['linkedEntityId'] as String?,
      hasFinishedOnboarding: (json['hasFinishedOnboarding'] as bool?) ?? false,
    );
  }

  User copyWith({
    String? id,
    String? phone,
    String? name,
    UserRole? role,
    String? address,
    String? avatar,
    String? factoryId,
    String? linkedEntityId,
    bool? hasFinishedOnboarding,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      role: role ?? this.role,
      address: address ?? this.address,
      avatar: avatar ?? this.avatar,
      factoryId: factoryId ?? this.factoryId,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
      hasFinishedOnboarding:
          hasFinishedOnboarding ?? this.hasFinishedOnboarding,
    );
  }
}
