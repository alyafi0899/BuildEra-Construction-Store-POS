// lib/features/products/domain/entities/product_entity.dart

class ProductEntity {
  final int? id;
  final String name;
  final String category;
  final String? barcode;
  final double basePrice;
  final String baseUnit;
  final double stockQuantity;
  final String? imagePath;
  final String? description;
  final bool isActive;
  final List<ProductUnitEntity> units;

  const ProductEntity({
    this.id,
    required this.name,
    required this.category,
    this.barcode,
    required this.basePrice,
    required this.baseUnit,
    required this.stockQuantity,
    this.imagePath,
    this.description,
    this.isActive = true,
    this.units = const [],
  });

  ProductEntity copyWith({
    int? id,
    String? name,
    String? category,
    String? barcode,
    double? basePrice,
    String? baseUnit,
    double? stockQuantity,
    String? imagePath,
    String? description,
    bool? isActive,
    List<ProductUnitEntity>? units,
  }) {
    return ProductEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      barcode: barcode ?? this.barcode,
      basePrice: basePrice ?? this.basePrice,
      baseUnit: baseUnit ?? this.baseUnit,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      imagePath: imagePath ?? this.imagePath,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      units: units ?? this.units,
    );
  }

  bool get isLowStock => stockQuantity <= 10;
  bool get isOutOfStock => stockQuantity <= 0;
}

class ProductUnitEntity {
  final int? id;
  final int productId;
  final String unitName;
  final double conversionRatio;
  final double sellingPrice;
  final bool isBaseUnit;

  const ProductUnitEntity({
    this.id,
    required this.productId,
    required this.unitName,
    required this.conversionRatio,
    required this.sellingPrice,
    this.isBaseUnit = false,
  });

  ProductUnitEntity copyWith({
    int? id,
    int? productId,
    String? unitName,
    double? conversionRatio,
    double? sellingPrice,
    bool? isBaseUnit,
  }) {
    return ProductUnitEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      unitName: unitName ?? this.unitName,
      conversionRatio: conversionRatio ?? this.conversionRatio,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      isBaseUnit: isBaseUnit ?? this.isBaseUnit,
    );
  }
}
