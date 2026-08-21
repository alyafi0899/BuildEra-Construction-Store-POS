import '../../features/products/models/product_financials.dart';

class ProductUnit {
  final String id;
  final String productId;
  final String unitName;
  final double conversionRate; // how many base units = 1 of this unit
  final double sellPrice;

  const ProductUnit({
    required this.id,
    required this.productId,
    required this.unitName,
    required this.conversionRate,
    required this.sellPrice,
  });

  factory ProductUnit.fromMap(Map<String, dynamic> m) => ProductUnit(
        id:             m['id'] as String? ?? '',
        productId:      m['product_id'] as String? ?? '',
        unitName:       m['unit_name'] as String? ?? '',
        conversionRate: (m['conversion_rate'] as num? ?? 1).toDouble(),
        sellPrice:      (m['sell_price'] as num? ?? 0).toDouble(),
      );

  Map<String, dynamic> toMap() => {
        'id':              id,
        'product_id':      productId,
        'unit_name':       unitName,
        'conversion_rate': conversionRate,
        'sell_price':      sellPrice,
      };

  ProductUnit copyWith({
    String? unitName,
    double? conversionRate,
    double? sellPrice,
  }) =>
      ProductUnit(
        id:             id,
        productId:      productId,
        unitName:       unitName ?? this.unitName,
        conversionRate: conversionRate ?? this.conversionRate,
        sellPrice:      sellPrice ?? this.sellPrice,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductUnit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          unitName == other.unitName;

  @override
  int get hashCode => id.hashCode ^ unitName.hashCode;
}

class Product {
  final String id;
  final String name;
  final String category;
  final String? barcode;
  final String? description; // New field
  final double costPrice;
  final double basePrice;
  final String baseUnit;
  final String? defaultUnitName;
  final double stock;
  final String? imagePath;
  final ProductFinancials financials;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductUnit> units;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    this.barcode,
    this.description,
    required this.costPrice,
    required this.basePrice,
    required this.baseUnit,
    this.defaultUnitName,
    required this.stock,
    this.imagePath,
    this.financials = const ProductFinancials(),
    required this.createdAt,
    required this.updatedAt,
    this.units = const [],
  });

  factory Product.fromMap(Map<String, dynamic> m) {
    final unitsData = m['units'] as List? ?? [];
    final units = unitsData
        .map((u) => ProductUnit.fromMap(Map<String, dynamic>.from(u as Map)))
        .toList();

    final id = m['id'] as String? ?? '';
    final barcode = m['barcode'] as String?;
    final name = m['name'] as String?;

    return Product(
      id: id,
      name: _sanitizeName(name, id, barcode),
      category: m['category'] as String? ?? 'Lainnya',
      barcode: barcode,
      description: m['description'] as String?,
      costPrice: (m['cost_price'] as num? ?? 0).toDouble(),
      basePrice: (m['base_price'] as num? ?? 0).toDouble(),
      baseUnit: m['base_unit'] as String? ?? 'pcs',
      defaultUnitName: m['default_unit_name'] as String?,
      stock: (m['stock'] as num? ?? 0).toDouble(),
      imagePath: m['image_path'] as String?,
      financials: ProductFinancials.fromMap(
          Map<String, dynamic>.from(m['financials'] as Map? ?? {})),
      createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(m['updated_at'] as String? ?? '') ??
          DateTime.now(),
      units: units,
    );
  }

  static String _sanitizeName(String? name, String id, String? barcode) {
    if (name != null && name.trim().isNotEmpty) return name.trim();
    if (barcode != null && barcode.trim().isNotEmpty) return 'Produk [$barcode]';
    return 'Tanpa Nama ${id.length > 5 ? id.substring(0, 5) : id}';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'barcode': barcode,
        'description': description,
        'cost_price': costPrice,
        'base_price': basePrice,
        'base_unit': baseUnit,
        'default_unit_name': defaultUnitName,
        'stock': stock,
        'image_path': imagePath,
        'financials': financials.toMap(),
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'units': units.map((u) => u.toMap()).toList(),
      };

  bool get isLowStock => stock <= 10;

  /// Returns the base unit as a ProductUnit object
  ProductUnit get baseProductUnit => ProductUnit(
    id:             'base',
    productId:      id,
    unitName:       baseUnit,
    conversionRate: 1,
    sellPrice:      basePrice,
  );

  /// Returns all available units for this product, including the base unit.
  /// Filters out duplicates to prevent UI crashes.
  List<ProductUnit> get allUnits {
    final base = baseProductUnit;
    // Only include additional units that don't have the same name as the base unit
    final additional = units.where((u) => u.unitName.toLowerCase() != baseUnit.toLowerCase());
    return [base, ...additional];
  }

  /// Sell price for a given unit (from the units list)
  double priceForUnit(String unitName) {
    final u = units.firstWhere(
      (u) => u.unitName == unitName,
      orElse: () => units.isNotEmpty ? units.first : ProductUnit(
        id: '', productId: id, unitName: baseUnit, conversionRate: 1, sellPrice: basePrice,
      ),
    );
    return u.sellPrice;
  }

  Product copyWith({
    String? id,
    String? name,
    String? category,
    String? barcode,
    String? description,
    double? costPrice,
    double? basePrice,
    String? baseUnit,
    String? defaultUnitName,
    double? stock,
    String? imagePath,
    ProductFinancials? financials,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProductUnit>? units,
  }) =>
      Product(
        id:        id ?? this.id,
        name:      name ?? this.name,
        category:  category ?? this.category,
        barcode:   barcode ?? this.barcode,
        description: description ?? this.description,
        costPrice: costPrice ?? this.costPrice,
        basePrice: basePrice ?? this.basePrice,
        baseUnit:  baseUnit ?? this.baseUnit,
        defaultUnitName: defaultUnitName ?? this.defaultUnitName,
        stock:     stock ?? this.stock,
        imagePath: imagePath ?? this.imagePath,
        financials: financials ?? this.financials,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
        units:     units ?? this.units,
      );
}
