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
        id:             m['id'] as String,
        productId:      m['product_id'] as String,
        unitName:       m['unit_name'] as String,
        conversionRate: (m['conversion_rate'] as num).toDouble(),
        sellPrice:      (m['sell_price'] as num).toDouble(),
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
}

class Product {
  final String id;
  final String name;
  final String category;
  final String? barcode;
  final double costPrice;
  final double basePrice;
  final String baseUnit;
  final double stock;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ProductUnit> units;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    this.barcode,
    required this.costPrice,
    required this.basePrice,
    required this.baseUnit,
    required this.stock,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
    this.units = const [],
  });

  factory Product.fromMap(Map<String, dynamic> m, {List<ProductUnit> units = const []}) =>
      Product(
        id:        m['id'] as String,
        name:      m['name'] as String,
        category:  m['category'] as String,
        barcode:   m['barcode'] as String?,
        costPrice: (m['cost_price'] as num? ?? 0).toDouble(),
        basePrice: (m['base_price'] as num).toDouble(),
        baseUnit:  m['base_unit'] as String,
        stock:     (m['stock'] as num).toDouble(),
        imagePath: m['image_path'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
        units:     units,
      );

  Map<String, dynamic> toMap() => {
        'id':          id,
        'name':        name,
        'category':    category,
        'barcode':     barcode,
        'cost_price':  costPrice,
        'base_price':  basePrice,
        'base_unit':   baseUnit,
        'stock':       stock,
        'image_path':  imagePath,
        'created_at':  createdAt.toIso8601String(),
        'updated_at':  updatedAt.toIso8601String(),
      };

  bool get isLowStock => stock <= 10;

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
    String? name,
    String? category,
    String? barcode,
    double? costPrice,
    double? basePrice,
    String? baseUnit,
    double? stock,
    String? imagePath,
    List<ProductUnit>? units,
  }) =>
      Product(
        id:        id,
        name:      name ?? this.name,
        category:  category ?? this.category,
        barcode:   barcode ?? this.barcode,
        costPrice: costPrice ?? this.costPrice,
        basePrice: basePrice ?? this.basePrice,
        baseUnit:  baseUnit ?? this.baseUnit,
        stock:     stock ?? this.stock,
        imagePath: imagePath ?? this.imagePath,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        units:     units ?? this.units,
      );
}
