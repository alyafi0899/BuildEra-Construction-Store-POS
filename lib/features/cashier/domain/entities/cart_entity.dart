// lib/features/cashier/domain/entities/cart_entity.dart
import '../../../../core/constants/app_constants.dart';

class CartItemEntity {
  final int productId;
  final String productName;
  final String unitName;
  final double quantity;
  final double pricePerUnit;
  final double subtotal;
  final double conversionRatio;
  final String baseUnit;
  final double maxStock;

  const CartItemEntity({
    required this.productId,
    required this.productName,
    required this.unitName,
    required this.quantity,
    required this.pricePerUnit,
    required this.subtotal,
    required this.conversionRatio,
    required this.baseUnit,
    required this.maxStock,
  });

  CartItemEntity copyWith({
    int? productId,
    String? productName,
    String? unitName,
    double? quantity,
    double? pricePerUnit,
    double? subtotal,
    double? conversionRatio,
    String? baseUnit,
    double? maxStock,
  }) {
    return CartItemEntity(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitName: unitName ?? this.unitName,
      quantity: quantity ?? this.quantity,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      subtotal: subtotal ?? this.subtotal,
      conversionRatio: conversionRatio ?? this.conversionRatio,
      baseUnit: baseUnit ?? this.baseUnit,
      maxStock: maxStock ?? this.maxStock,
    );
  }

  // Stock consumption in base units
  double get baseUnitQuantity => quantity * conversionRatio;
}

class CartState {
  final List<CartItemEntity> items;
  final double discountAmount;
  final double discountPercent;
  final bool taxEnabled;
  final String customerName;
  final String notes;

  const CartState({
    this.items = const [],
    this.discountAmount = 0,
    this.discountPercent = 0,
    this.taxEnabled = true,
    this.customerName = '',
    this.notes = '',
  });

  double get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);
  double get taxAmount => taxEnabled ? (subtotal - discountAmount) * AppConstants.taxRate : 0;
  double get total => subtotal - discountAmount + taxAmount;
  int get itemCount => items.length;
  bool get isEmpty => items.isEmpty;

  CartState copyWith({
    List<CartItemEntity>? items,
    double? discountAmount,
    double? discountPercent,
    bool? taxEnabled,
    String? customerName,
    String? notes,
  }) {
    return CartState(
      items: items ?? this.items,
      discountAmount: discountAmount ?? this.discountAmount,
      discountPercent: discountPercent ?? this.discountPercent,
      taxEnabled: taxEnabled ?? this.taxEnabled,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
    );
  }
}
