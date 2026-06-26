class ShippingService {
  final String id;
  final String name;
  final String? phone;
  final DateTime createdAt;

  const ShippingService({
    required this.id,
    required this.name,
    this.phone,
    required this.createdAt,
  });

  factory ShippingService.fromMap(Map<String, dynamic> m) => ShippingService(
        id:        m['id'] as String,
        name:      m['name'] as String,
        phone:     m['phone'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id':         id,
        'name':       name,
        'phone':      phone,
        'created_at': createdAt.toIso8601String(),
      };

  ShippingService copyWith({
    String? name,
    String? phone,
  }) =>
      ShippingService(
        id:        id,
        name:      name ?? this.name,
        phone:     phone ?? this.phone,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShippingService && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
