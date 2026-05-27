// lib/data/hive/hive_models.dart
//
// Manual TypeAdapters — tidak perlu build_runner / hive_generator.
// Hive typeId registry:
//   0 = HiveProductUnit
//   1 = HiveProduct
//   2 = HiveTransactionItem
//   3 = HiveTransaction

import 'package:hive_flutter/hive_flutter.dart';
import '../../features/products/domain/entities/product_entity.dart';

// ─── PRODUCT UNIT ─────────────────────────────────────────────────────────────

class HiveProductUnit {
  int id;
  int productId;
  String unitName;
  double conversionRatio;
  double sellingPrice;
  bool isBaseUnit;

  HiveProductUnit({
    required this.id,
    required this.productId,
    required this.unitName,
    required this.conversionRatio,
    required this.sellingPrice,
    required this.isBaseUnit,
  });

  ProductUnitEntity toEntity() => ProductUnitEntity(
        id: id,
        productId: productId,
        unitName: unitName,
        conversionRatio: conversionRatio,
        sellingPrice: sellingPrice,
        isBaseUnit: isBaseUnit,
      );

  factory HiveProductUnit.fromEntity(ProductUnitEntity e) => HiveProductUnit(
        id: e.id ?? 0,
        productId: e.productId,
        unitName: e.unitName,
        conversionRatio: e.conversionRatio,
        sellingPrice: e.sellingPrice,
        isBaseUnit: e.isBaseUnit,
      );
}

class HiveProductUnitAdapter extends TypeAdapter<HiveProductUnit> {
  @override
  final int typeId = 0;

  @override
  HiveProductUnit read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return HiveProductUnit(
      id: (fields[0] as num).toInt(),
      productId: (fields[1] as num).toInt(),
      unitName: fields[2] as String,
      conversionRatio: (fields[3] as num).toDouble(),
      sellingPrice: (fields[4] as num).toDouble(),
      isBaseUnit: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, HiveProductUnit obj) {
    writer.writeByte(6);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.productId);
    writer.writeByte(2); writer.write(obj.unitName);
    writer.writeByte(3); writer.write(obj.conversionRatio);
    writer.writeByte(4); writer.write(obj.sellingPrice);
    writer.writeByte(5); writer.write(obj.isBaseUnit);
  }
}

// ─── PRODUCT ──────────────────────────────────────────────────────────────────

class HiveProduct {
  int id;
  String name;
  String category;
  String? barcode;
  double basePrice;
  String baseUnit;
  double stockQuantity;
  String? description;
  bool isActive;
  List<HiveProductUnit> units;

  HiveProduct({
    required this.id,
    required this.name,
    required this.category,
    this.barcode,
    required this.basePrice,
    required this.baseUnit,
    required this.stockQuantity,
    this.description,
    required this.isActive,
    required this.units,
  });

  ProductEntity toEntity() => ProductEntity(
        id: id,
        name: name,
        category: category,
        barcode: barcode,
        basePrice: basePrice,
        baseUnit: baseUnit,
        stockQuantity: stockQuantity,
        description: description,
        isActive: isActive,
        units: units.map((u) => u.toEntity()).toList(),
      );

  factory HiveProduct.fromEntity(ProductEntity e, {List<HiveProductUnit>? units}) =>
      HiveProduct(
        id: e.id ?? 0,
        name: e.name,
        category: e.category,
        barcode: e.barcode,
        basePrice: e.basePrice,
        baseUnit: e.baseUnit,
        stockQuantity: e.stockQuantity,
        description: e.description,
        isActive: e.isActive,
        units: units ?? e.units.map(HiveProductUnit.fromEntity).toList(),
      );

  HiveProduct copyWith({double? stockQuantity}) => HiveProduct(
        id: id,
        name: name,
        category: category,
        barcode: barcode,
        basePrice: basePrice,
        baseUnit: baseUnit,
        stockQuantity: stockQuantity ?? this.stockQuantity,
        description: description,
        isActive: isActive,
        units: units,
      );
}

class HiveProductAdapter extends TypeAdapter<HiveProduct> {
  @override
  final int typeId = 1;

  @override
  HiveProduct read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return HiveProduct(
      id: (fields[0] as num).toInt(),
      name: fields[1] as String,
      category: fields[2] as String,
      barcode: fields[3] as String?,
      basePrice: (fields[4] as num).toDouble(),
      baseUnit: fields[5] as String,
      stockQuantity: (fields[6] as num).toDouble(),
      description: fields[7] as String?,
      isActive: fields[8] as bool,
      units: (fields[9] as List).cast<HiveProductUnit>(),
    );
  }

  @override
  void write(BinaryWriter writer, HiveProduct obj) {
    writer.writeByte(10);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.name);
    writer.writeByte(2); writer.write(obj.category);
    writer.writeByte(3); writer.write(obj.barcode);
    writer.writeByte(4); writer.write(obj.basePrice);
    writer.writeByte(5); writer.write(obj.baseUnit);
    writer.writeByte(6); writer.write(obj.stockQuantity);
    writer.writeByte(7); writer.write(obj.description);
    writer.writeByte(8); writer.write(obj.isActive);
    writer.writeByte(9); writer.write(obj.units);
  }
}

// ─── TRANSACTION ITEM ─────────────────────────────────────────────────────────

class HiveTransactionItem {
  int id;
  int transactionId;
  int productId;
  String productName;
  String unitName;
  double quantity;
  double pricePerUnit;
  double subtotal;
  double conversionRatio;

  HiveTransactionItem({
    required this.id,
    required this.transactionId,
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.quantity,
    required this.pricePerUnit,
    required this.subtotal,
    required this.conversionRatio,
  });
}

class HiveTransactionItemAdapter extends TypeAdapter<HiveTransactionItem> {
  @override
  final int typeId = 2;

  @override
  HiveTransactionItem read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{};
    for (int i = 0; i < n; i++) {
      f[reader.readByte()] = reader.read();
    }
    return HiveTransactionItem(
      id: (f[0] as num).toInt(),
      transactionId: (f[1] as num).toInt(),
      productId: (f[2] as num).toInt(),
      productName: f[3] as String,
      unitName: f[4] as String,
      quantity: (f[5] as num).toDouble(),
      pricePerUnit: (f[6] as num).toDouble(),
      subtotal: (f[7] as num).toDouble(),
      conversionRatio: (f[8] as num).toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, HiveTransactionItem obj) {
    writer.writeByte(9);
    writer.writeByte(0); writer.write(obj.id);
    writer.writeByte(1); writer.write(obj.transactionId);
    writer.writeByte(2); writer.write(obj.productId);
    writer.writeByte(3); writer.write(obj.productName);
    writer.writeByte(4); writer.write(obj.unitName);
    writer.writeByte(5); writer.write(obj.quantity);
    writer.writeByte(6); writer.write(obj.pricePerUnit);
    writer.writeByte(7); writer.write(obj.subtotal);
    writer.writeByte(8); writer.write(obj.conversionRatio);
  }
}

// ─── TRANSACTION ──────────────────────────────────────────────────────────────

class HiveTransaction {
  int id;
  String transactionCode;
  DateTime transactionDate;
  double subtotal;
  double discountAmount;
  double taxAmount;
  double totalAmount;
  double paidAmount;
  double changeAmount;
  String paymentMethod;
  String? notes;
  String status;
  String cashierName;
  List<HiveTransactionItem> items;

  HiveTransaction({
    required this.id,
    required this.transactionCode,
    required this.transactionDate,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    required this.paymentMethod,
    this.notes,
    required this.status,
    required this.cashierName,
    required this.items,
  });
}

class HiveTransactionAdapter extends TypeAdapter<HiveTransaction> {
  @override
  final int typeId = 3;

  @override
  HiveTransaction read(BinaryReader reader) {
    final n = reader.readByte();
    final f = <int, dynamic>{};
    for (int i = 0; i < n; i++) {
      f[reader.readByte()] = reader.read();
    }
    return HiveTransaction(
      id: (f[0] as num).toInt(),
      transactionCode: f[1] as String,
      transactionDate: f[2] as DateTime,
      subtotal: (f[3] as num).toDouble(),
      discountAmount: (f[4] as num).toDouble(),
      taxAmount: (f[5] as num).toDouble(),
      totalAmount: (f[6] as num).toDouble(),
      paidAmount: (f[7] as num).toDouble(),
      changeAmount: (f[8] as num).toDouble(),
      paymentMethod: f[9] as String,
      notes: f[10] as String?,
      status: f[11] as String,
      cashierName: f[12] as String,
      items: (f[13] as List).cast<HiveTransactionItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, HiveTransaction obj) {
    writer.writeByte(14);
    writer.writeByte(0);  writer.write(obj.id);
    writer.writeByte(1);  writer.write(obj.transactionCode);
    writer.writeByte(2);  writer.write(obj.transactionDate);
    writer.writeByte(3);  writer.write(obj.subtotal);
    writer.writeByte(4);  writer.write(obj.discountAmount);
    writer.writeByte(5);  writer.write(obj.taxAmount);
    writer.writeByte(6);  writer.write(obj.totalAmount);
    writer.writeByte(7);  writer.write(obj.paidAmount);
    writer.writeByte(8);  writer.write(obj.changeAmount);
    writer.writeByte(9);  writer.write(obj.paymentMethod);
    writer.writeByte(10); writer.write(obj.notes);
    writer.writeByte(11); writer.write(obj.status);
    writer.writeByte(12); writer.write(obj.cashierName);
    writer.writeByte(13); writer.write(obj.items);
  }
}
