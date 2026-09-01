import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/product.dart';

final _uuid = Uuid();

class PurchaseCartItem {
  final String id;
  final Product product;
  final ProductUnit unit;
  final double quantity;
  final double purchasePrice; // Price per unit (not base unit)

  const PurchaseCartItem({
    required this.id,
    required this.product,
    required this.unit,
    required this.quantity,
    required this.purchasePrice,
  });

  double get subtotal => quantity * purchasePrice;

  PurchaseCartItem copyWith({
    Product? product,
    ProductUnit? unit,
    double? quantity,
    double? purchasePrice,
  }) =>
      PurchaseCartItem(
        id:            id,
        product:       product       ?? this.product,
        unit:          unit          ?? this.unit,
        quantity:      quantity      ?? this.quantity,
        purchasePrice: purchasePrice ?? this.purchasePrice,
      );
}

class PurchaseCartState {
  final List<PurchaseCartItem> items;
  final String? supplierId;
  final String? supplierName;
  final double shippingFee;

  const PurchaseCartState({
    this.items        = const [],
    this.supplierId,
    this.supplierName,
    this.shippingFee  = 0,
  });

  double get subtotal => items.fold(0, (s, i) => s + i.subtotal);
  double get total    => subtotal + shippingFee;
  int    get itemCount => items.length;
  bool   get isEmpty   => items.isEmpty;

  PurchaseCartState copyWith({
    List<PurchaseCartItem>? items,
    String? supplierId,
    String? supplierName,
    double? shippingFee,
  }) =>
      PurchaseCartState(
        items:        items        ?? this.items,
        supplierId:   supplierId   ?? this.supplierId,
        supplierName: supplierName ?? this.supplierName,
        shippingFee:  shippingFee  ?? this.shippingFee,
      );
}

class PurchaseCartNotifier extends Notifier<PurchaseCartState> {
  @override
  PurchaseCartState build() => const PurchaseCartState();

  void addProduct(Product product, {ProductUnit? unit}) {
    final u = unit ?? product.allUnits.first;
    
    final existing = state.items.indexWhere(
      (i) => i.product.id == product.id && i.unit.unitName == u.unitName,
    );

    if (existing >= 0) {
      final updated = List<PurchaseCartItem>.from(state.items);
      updated[existing] = updated[existing].copyWith(
        quantity: updated[existing].quantity + 1,
      );
      state = state.copyWith(items: updated);
    } else {
      state = state.copyWith(items: [
        ...state.items,
        PurchaseCartItem(
          id:            _uuid.v4(),
          product:       product,
          unit:          u,
          quantity:      1,
          purchasePrice: product.costPrice * u.conversionRate,
        ),
      ]);
    }
  }

  void updateQuantity(String itemId, double qty) {
    if (qty < 0) return;
    state = state.copyWith(
      items: state.items.map((i) => i.id == itemId ? i.copyWith(quantity: qty) : i).toList(),
    );
  }

  void updatePurchasePrice(String itemId, double price) {
    if (price < 0) return;
    state = state.copyWith(
      items: state.items.map((i) => i.id == itemId ? i.copyWith(purchasePrice: price) : i).toList(),
    );
  }

  void updateUnit(String itemId, ProductUnit unit) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == itemId) {
          return i.copyWith(
            unit:          unit,
            purchasePrice: i.product.costPrice * unit.conversionRate,
          );
        }
        return i;
      }).toList(),
    );
  }

  void removeItem(String itemId) {
    state = state.copyWith(items: state.items.where((i) => i.id != itemId).toList());
  }

  void setSupplier(String? id, String? name) => 
      state = state.copyWith(supplierId: id, supplierName: name);

  void setShippingFee(double fee) => 
      state = state.copyWith(shippingFee: fee);

  void clear() => state = const PurchaseCartState();
}

final purchaseCartProvider = NotifierProvider<PurchaseCartNotifier, PurchaseCartState>(PurchaseCartNotifier.new);
