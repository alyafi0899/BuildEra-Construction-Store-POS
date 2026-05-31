import '../../../shared/models/product.dart';

class CartItem {
  final String id;
  final Product product;
  final ProductUnit selectedUnit;
  final double quantity;

  const CartItem({
    required this.id,
    required this.product,
    required this.selectedUnit,
    required this.quantity,
  });

  double get subtotal => selectedUnit.sellPrice * quantity;

  CartItem copyWith({
    ProductUnit? selectedUnit,
    double? quantity,
  }) =>
      CartItem(
        id:           id,
        product:      product,
        selectedUnit: selectedUnit ?? this.selectedUnit,
        quantity:     quantity ?? this.quantity,
      );
}
