class StoreAdmin {
  final String id;
  final String userId;
  final String name;
  final String pinHash;
  final String pinSalt;
  final int pinIterations;
  final String role;
  final bool isActive;
  final bool canEditPrice;
  final bool canGiveDiscount;
  final bool canVoid;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StoreAdmin({
    required this.id,
    required this.userId,
    required this.name,
    required this.pinHash,
    required this.pinSalt,
    this.pinIterations = 20000,
    this.role = 'cashier',
    this.isActive = true,
    this.canEditPrice = true,
    this.canGiveDiscount = true,
    this.canVoid = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StoreAdmin.fromMap(Map<String, dynamic> map) {
    return StoreAdmin(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      pinHash: (map['pin_hash'] ?? '').toString(),
      pinSalt: (map['pin_salt'] ?? '').toString(),
      pinIterations: (map['pin_iterations'] as num? ?? 20000).toInt(),
      role: (map['role'] ?? 'cashier').toString(),
      isActive: map['is_active'] == true || map['is_active']?.toString().toLowerCase() == 'true',
      canEditPrice: map['can_edit_price'] == true || map['can_edit_price']?.toString().toLowerCase() == 'true',
      canGiveDiscount: map['can_give_discount'] == true || map['can_give_discount']?.toString().toLowerCase() == 'true',
      canVoid: map['can_void'] == true || map['can_void']?.toString().toLowerCase() == 'true',
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'pin_hash': pinHash,
      'pin_salt': pinSalt,
      'pin_iterations': pinIterations,
      'role': role,
      'is_active': isActive,
      'can_edit_price': canEditPrice,
      'can_give_discount': canGiveDiscount,
      'can_void': canVoid,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StoreAdmin copyWith({
    String? id,
    String? userId,
    String? name,
    String? pinHash,
    String? pinSalt,
    int? pinIterations,
    String? role,
    bool? isActive,
    bool? canEditPrice,
    bool? canGiveDiscount,
    bool? canVoid,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreAdmin(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      pinHash: pinHash ?? this.pinHash,
      pinSalt: pinSalt ?? this.pinSalt,
      pinIterations: pinIterations ?? this.pinIterations,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      canEditPrice: canEditPrice ?? this.canEditPrice,
      canGiveDiscount: canGiveDiscount ?? this.canGiveDiscount,
      canVoid: canVoid ?? this.canVoid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
