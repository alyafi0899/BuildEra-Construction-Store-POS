// lib/features/cashier/presentation/providers/cart_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cart_entity.dart';
import '../../../products/domain/entities/product_entity.dart';

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void addItem(ProductEntity product, ProductUnitEntity unit, double quantity) {
    final existingIndex = state.items.indexWhere(
      (item) => item.productId == product.id && item.unitName == unit.unitName,
    );

    if (existingIndex >= 0) {
      final updatedItems = [...state.items];
      final existing = updatedItems[existingIndex];
      updatedItems[existingIndex] = existing.copyWith(
        quantity: existing.quantity + quantity,
        subtotal: (existing.quantity + quantity) * unit.sellingPrice,
      );
      state = state.copyWith(items: updatedItems);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        CartItemEntity(
          productId: product.id!,
          productName: product.name,
          unitName: unit.unitName,
          quantity: quantity,
          pricePerUnit: unit.sellingPrice,
          subtotal: quantity * unit.sellingPrice,
          conversionRatio: unit.conversionRatio,
          baseUnit: product.baseUnit,
          maxStock: product.stockQuantity,
        ),
      ]);
    }
  }

  void updateItemQuantity(int index, double quantity) {
    if (index < 0 || index >= state.items.length) return;
    if (quantity <= 0) { removeItem(index); return; }
    final updatedItems = [...state.items];
    final item = updatedItems[index];
    updatedItems[index] = item.copyWith(
      quantity: quantity,
      subtotal: quantity * item.pricePerUnit,
    );
    state = state.copyWith(items: updatedItems);
  }

  void removeItem(int index) {
    final updatedItems = [...state.items];
    updatedItems.removeAt(index);
    state = state.copyWith(items: updatedItems);
  }

  void setDiscountPercent(double percent) {
    final discount = state.subtotal * (percent / 100);
    state = state.copyWith(discountAmount: discount, discountPercent: percent);
  }

  void setTaxEnabled(bool enabled) => state = state.copyWith(taxEnabled: enabled);
  void setNotes(String notes) => state = state.copyWith(notes: notes);
  void clearCart() => state = const CartState();
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

final cashierSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedCategoryFilterProvider = StateProvider<String?>((ref) => null);
