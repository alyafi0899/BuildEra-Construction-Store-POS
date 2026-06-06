import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/product.dart';
import '../models/cart_item.dart';

final _uuid = Uuid();

// ── Cart State ────────────────────────────────────────────────────────────

class CartState {
  final List<CartItem> items;
  final double transDiscountValue;
  final DiscountType transDiscountType;
  final double taxRate;
  final bool taxEnabled;
  final String? customerName;

  const CartState({
    this.items               = const [],
    this.transDiscountValue  = 0,
    this.transDiscountType   = DiscountType.fixed,
    this.taxRate             = 0.11,
    this.taxEnabled          = false,
    this.customerName,
  });

  /// Sum of (soldPrice * quantity) - BEFORE item-level discounts
  double get grossSubtotal => items.fold(0, (s, i) => s + i.totalBeforeDiscount);

  /// Total of all item-level discounts
  double get itemDiscountTotal => items.fold(0, (s, i) => s + i.totalDiscount);

  /// Subtotal after item discounts, before transaction discount
  double get netSubtotal => grossSubtotal - itemDiscountTotal;

  /// Amount of transaction-level discount
  double get transDiscountAmount {
    if (transDiscountValue == 0) return 0;
    if (transDiscountType == DiscountType.percentage) {
      return netSubtotal * (transDiscountValue / 100);
    }
    return transDiscountValue;
  }

  /// Total discount (Item + Transaction)
  double get totalDiscount => itemDiscountTotal + transDiscountAmount;

  double get taxAmount  => taxEnabled ? (netSubtotal - transDiscountAmount) * taxRate : 0;
  double get total      => netSubtotal - transDiscountAmount + taxAmount;
  
  int    get itemCount  => items.length;
  bool   get isEmpty    => items.isEmpty;

  CartState copyWith({
    List<CartItem>? items,
    double? transDiscountValue,
    DiscountType? transDiscountType,
    double? taxRate,
    bool? taxEnabled,
    String? customerName,
  }) =>
      CartState(
        items:               items              ?? this.items,
        transDiscountValue:  transDiscountValue  ?? this.transDiscountValue,
        transDiscountType:   transDiscountType   ?? this.transDiscountType,
        taxRate:             taxRate            ?? this.taxRate,
        taxEnabled:          taxEnabled         ?? this.taxEnabled,
        customerName:        customerName       ?? this.customerName,
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
        CartItem(
          id:            _uuid.v4(),
          product:       product,
          selectedUnit:  u,
          quantity:      1,
          costPrice:     product.costPrice * u.conversionRate,
          originalPrice: u.sellPrice,
          soldPrice:     u.sellPrice,
        ),
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
        if (i.id == cartItemId) {
          return i.copyWith(
            selectedUnit:  unit,
            costPrice:     i.product.costPrice * unit.conversionRate,
            originalPrice: unit.sellPrice,
            soldPrice:     unit.sellPrice, // Reset override on unit change? Usually yes.
          );
        }
        return i;
      }).toList(),
    );
  }

  void updateSoldPrice(String cartItemId, double price) {
    if (price < 0) return;
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == cartItemId) return i.copyWith(soldPrice: price);
        return i;
      }).toList(),
    );
  }

  void setItemDiscount(String cartItemId, double value, DiscountType type) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == cartItemId) return i.copyWith(discountValue: value, discountType: type);
        return i;
      }).toList(),
    );
  }

  void removeItem(String cartItemId) {
    state = state.copyWith(items: state.items.where((i) => i.id != cartItemId).toList());
  }

  void setTransDiscount(double v, DiscountType type) => 
      state = state.copyWith(transDiscountValue: v, transDiscountType: type);

  void setCustomer(String? name) => state = state.copyWith(customerName: name);
  
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
