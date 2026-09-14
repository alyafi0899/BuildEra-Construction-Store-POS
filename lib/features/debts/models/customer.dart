class Customer {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final double totalOutstanding;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.totalOutstanding = 0,
  });

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id:               m['id']?.toString() ?? '',
        name:             m['name']?.toString() ?? '',
        phone:            m['phone']?.toString() ?? '',
        address:          m['address']?.toString(),
        notes:            m['notes']?.toString(),
        createdAt:        DateTime.parse(m['created_at']?.toString() ?? DateTime.now().toIso8601String()),
        updatedAt:        m['updated_at'] != null ? DateTime.parse(m['updated_at'].toString()) : DateTime.parse(m['created_at']?.toString() ?? DateTime.now().toIso8601String()),
        isActive:         m['is_active'] as bool? ?? true,
        totalOutstanding: (m['total_outstanding'] as num? ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id':                id,
        'name':              name,
        'phone':             phone,
        'address':           address,
        'notes':             notes,
        'created_at':        createdAt.toIso8601String(),
        'updated_at':        updatedAt.toIso8601String(),
        'is_active':         isActive,
        'total_outstanding': totalOutstanding,
      };

  Customer copyWith({
    String? name,
    String? phone,
    String? address,
    String? notes,
    bool? isActive,
    double? totalOutstanding,
    DateTime? updatedAt,
  }) =>
      Customer(
        id:               id,
        name:             name ?? this.name,
        phone:            phone ?? this.phone,
        address:          address ?? this.address,
        notes:            notes ?? this.notes,
        createdAt:        createdAt,
        updatedAt:        updatedAt ?? this.updatedAt,
        isActive:         isActive ?? this.isActive,
        totalOutstanding: totalOutstanding ?? this.totalOutstanding,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
