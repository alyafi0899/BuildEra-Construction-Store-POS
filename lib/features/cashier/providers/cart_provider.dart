import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/product.dart';
import '../models/cart_item.dart';

final _uuid = Uuid();

// ── Cart State ────────────────────────────────────────────────────────────

class CartState {
  final List<CartItem> items;
  final double discount;
  final double taxRate;
  final bool taxEnabled;

  const CartState({
    this.items      = const [],
    this.discount   = 0,
    this.taxRate    = 0.11,
    this.taxEnabled = false,
  });

  double get subtotal   => items.fold(0, (s, i) => s + i.subtotal);
  double get taxAmount  => taxEnabled ? subtotal * taxRate : 0;
  double get total      => subtotal - discount + taxAmount;
  int    get itemCount  => items.length;
  bool   get isEmpty    => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    double? discount,
    double? taxRate,
    bool? taxEnabled,
  }) =>
      CartState(
        items:      items      ?? this.items,
        discount:   discount   ?? this.discount,
        taxRate:    taxRate    ?? this.taxRate,
        taxEnabled: taxEnabled ?? this.taxEnabled,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  void addProduct(Product product, {ProductUnit? unit}) {
    final u = unit ?? (product.units.isNotEmpty ? product.units.first : _defaultUnit(product));
    final existing = state.items.indexWhere(
      (i) => i.product.id == product.id && i.selectedUnit.unitName == u.unitName,
    );
    if (existing >= 0) {
      final updated = List<CartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + 1,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        CartItem(id: _uuid.v4(), product: product, selectedUnit: u, quantity: 1),
      ]);
    }
  }

  void updateQuantity(String cartItemId, double qty) {
    if (qty <= 0) {
      removeItem(cartItemId);
      return;
    }
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == cartItemId) return i.copyWith(quantity: qty);
        return i;
      }).toList(),
    );
  }

  void updateUnit(String cartItemId, ProductUnit unit) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == cartItemId) return i.copyWith(selectedUnit: unit);
        return i;
      }).toList(),
    );
  }

  void removeItem(String cartItemId) {
    state = state.copyWith(items: state.items.where((i) => i.id != cartItemId).toList());
  }

  void setDiscount(double v) => state = state.copyWith(discount: v);
  void toggleTax()           => state = state.copyWith(taxEnabled: !state.taxEnabled);
  void setTaxRate(double r)  => state = state.copyWith(taxRate: r);

  void clear() => state = const CartState();

  ProductUnit _defaultUnit(Product p) => ProductUnit(
        id:             '',
        productId:      p.id,
        unitName:       p.baseUnit,
        conversionRate: 1,
        sellPrice:      p.basePrice,
      );
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);
