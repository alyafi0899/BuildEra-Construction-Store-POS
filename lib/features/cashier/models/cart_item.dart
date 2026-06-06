import '../../../shared/models/product.dart';

enum DiscountType { percentage, fixed }

class CartItem {
  final String id;
  final Product product;
  final ProductUnit selectedUnit;
  final double quantity;
  
  /// The cost price of the unit at the time it was added
  final double costPrice;
  
  /// The base selling price of the unit at the time it was added
  final double originalPrice;
  
  /// The actual selling price after manual override (Harga Kurang)
  final double soldPrice;
  
  /// Discount value applied to this item
  final double discountValue;
  final DiscountType discountType;

  const CartItem({
    required this.id,
    required this.product,
    required this.selectedUnit,
    required this.quantity,
    required this.costPrice,
    required this.originalPrice,
    required this.soldPrice,
    this.discountValue = 0,
    this.discountType = DiscountType.fixed,
  });

  /// Total price for this line before item-level discount
  double get totalBeforeDiscount => soldPrice * quantity;

  /// Total cost for this line
  double get totalCost => costPrice * quantity;

  /// Profit for this line
  double get profit => subtotal - totalCost;

  /// Total discount amount for this line
  double get totalDiscount {
    if (discountValue == 0) return 0;
    if (discountType == DiscountType.percentage) {
      return (soldPrice * (discountValue / 100)) * quantity;
    }
    return discountValue * quantity;
  }

  /// Final subtotal for this item line
  double get subtotal => totalBeforeDiscount - totalDiscount;

  /// Checks if the price has been overridden
  bool get isOverridden => soldPrice != originalPrice;

  CartItem copyWith({
    ProductUnit? selectedUnit,
    double? quantity,
    double? costPrice,
    double? originalPrice,
    double? soldPrice,
    double? discountValue,
    DiscountType? discountType,
  }) =>
      CartItem(
        id:           id,
        product:      product,
        selectedUnit: selectedUnit ?? this.selectedUnit,
        quantity:     quantity ?? this.quantity,
        costPrice:    costPrice ?? this.costPrice,
        originalPrice: originalPrice ?? this.originalPrice,
        soldPrice:    soldPrice ?? this.soldPrice,
        discountValue: discountValue ?? this.discountValue,
        discountType:  discountType ?? this.discountType,
      );
}
