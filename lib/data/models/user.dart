enum UserRole { owner, delivery }

class User {
  final String id;
  final String email;
  final String password;
  final String name;
  final UserRole role;
  final String? phone;
  final String? address;
  final String? avatar;
  final String? factoryId;
  final String? linkedEntityId;
  final bool hasFinishedOnboarding;
  /// When true (e.g. new driver accounts), the app prompts for a password change after login.
  final bool mustChangePassword;

  const User({
    required this.id,
    required this.email,
    required this.password,
    required this.name,
    required this.role,
    this.phone,
    this.address,
    this.avatar,
    this.factoryId,
    this.linkedEntityId,
    this.hasFinishedOnboarding = false,
    this.mustChangePassword = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'password': password,
      'name': name,
      'role': role.name,
      'phone': phone,
      'address': address,
      'avatar': avatar,
      'factoryId': factoryId,
      'linkedEntityId': linkedEntityId,
      'hasFinishedOnboarding': hasFinishedOnboarding,
      'mustChangePassword': mustChangePassword,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      password: (json['password'] as String?) ?? '',
      name: json['name'] as String,
      role: UserRole.values.byName(json['role'] as String),
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      avatar: json['avatar'] as String?,
      factoryId: json['factoryId'] as String?,
      linkedEntityId: json['linkedEntityId'] as String?,
      hasFinishedOnboarding: (json['hasFinishedOnboarding'] as bool?) ?? false,
      mustChangePassword: (json['mustChangePassword'] as bool?) ?? false,
    );
  }

  User copyWith({
    String? id,
    String? email,
    String? password,
    String? name,
    UserRole? role,
    String? phone,
    String? address,
    String? avatar,
    String? factoryId,
    String? linkedEntityId,
    bool? hasFinishedOnboarding,
    bool? mustChangePassword,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      avatar: avatar ?? this.avatar,
      factoryId: factoryId ?? this.factoryId,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
      hasFinishedOnboarding:
          hasFinishedOnboarding ?? this.hasFinishedOnboarding,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
    );
  }
}
