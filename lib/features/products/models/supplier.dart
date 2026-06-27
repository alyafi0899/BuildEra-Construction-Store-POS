class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final DateTime createdAt;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    required this.createdAt,
  });

  factory Supplier.fromMap(Map<String, dynamic> m) => Supplier(
        id:        m['id'] as String,
        name:      m['name'] as String,
        phone:     m['phone'] as String?,
        address:   m['address'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id':         id,
        'name':       name,
        'phone':      phone,
        'address':    address,
        'created_at': createdAt.toIso8601String(),
      };

  Supplier copyWith({
    String? name,
    String? phone,
    String? address,
  }) =>
      Supplier(
        id:        id,
        name:      name ?? this.name,
        phone:     phone ?? this.phone,
        address:   address ?? this.address,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Supplier && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
