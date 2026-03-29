class Factory {
  final String id;
  final String name;
  final String address;
  final String? phone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Factory({
    required this.id,
    required this.name,
    required this.address,
    this.phone,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Factory.fromJson(Map<String, dynamic> json) {
    return Factory(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
