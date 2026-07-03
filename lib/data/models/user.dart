enum UserRole { owner, delivery }

/// Workspace billing tier. New sign-ups start on [free].
enum SubscriptionPlan { free, pro }

class User {
  final String id;
  final String phone;
  final String name;
  final UserRole role;
  final SubscriptionPlan plan;
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
    this.plan = SubscriptionPlan.free,
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
      'plan': plan.name,
      'address': address,
      'avatar': avatar,
      'factoryId': factoryId,
      'linkedEntityId': linkedEntityId,
      'hasFinishedOnboarding': hasFinishedOnboarding,
    };
  }

  static SubscriptionPlan _planFromJson(Map<String, dynamic> json) {
    final raw = json['plan'] as String?;
    if (raw == null) return SubscriptionPlan.free;
    return SubscriptionPlan.values.asNameMap()[raw] ?? SubscriptionPlan.free;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      phone: (json['phone'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      role: UserRole.values.byName((json['role'] as String?) ?? 'owner'),
      plan: _planFromJson(json),
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
    SubscriptionPlan? plan,
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
      plan: plan ?? this.plan,
      address: address ?? this.address,
      avatar: avatar ?? this.avatar,
      factoryId: factoryId ?? this.factoryId,
      linkedEntityId: linkedEntityId ?? this.linkedEntityId,
      hasFinishedOnboarding:
          hasFinishedOnboarding ?? this.hasFinishedOnboarding,
    );
  }
}
