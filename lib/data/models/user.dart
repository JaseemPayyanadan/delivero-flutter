enum UserRole {
  owner,
  delivery,
}

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
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      'phone': phone,
      'address': address,
      'avatar': avatar,
      'factoryId': factoryId,
      'linkedEntityId': linkedEntityId,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      password: '', // We don't persist password usually
      name: json['name'] as String,
      role: UserRole.values.byName(json['role'] as String),
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      avatar: json['avatar'] as String?,
      factoryId: json['factoryId'] as String?,
      linkedEntityId: json['linkedEntityId'] as String?,
    );
  }
}
