import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItemFocusNodes {
  final FocusNode qtyFocus;
  final FocusNode priceFocus;
  final FocusNode discountFocus;

  CartItemFocusNodes({
    required this.qtyFocus,
    required this.priceFocus,
    required this.discountFocus,
  });

  void dispose() {
    qtyFocus.dispose();
    priceFocus.dispose();
    discountFocus.dispose();
  }
}

class CartFocusRegistry extends Notifier<Map<String, CartItemFocusNodes>> {
  @override
  Map<String, CartItemFocusNodes> build() => {};

  void register(String itemId, CartItemFocusNodes nodes) {
    state = {...state, itemId: nodes};
  }

  void unregister(String itemId) {
    if (state.containsKey(itemId)) {
      final newState = Map<String, CartItemFocusNodes>.from(state);
      newState.remove(itemId);
      state = newState;
    }
  }

  @override
  // Note: dispose in Notifier is handled by the provider container
  // but if we need a custom cleanup when the notifier itself is destroyed:
  void dispose() {
    // Note: In Riverpod 2.x Notifier, there isn't a direct @override dispose() 
    // like in StateNotifier. Instead we use ref.onDispose in build if needed.
    // However, since these are FocusNodes attached to UI, we'll let the UI dispose them.
  }
}

final cartFocusRegistryProvider =
    NotifierProvider<CartFocusRegistry, Map<String, CartItemFocusNodes>>(CartFocusRegistry.new);

// Helper provider for specific fields in CartPanel totals
class CartTotalsFocus {
  final FocusNode transDiscountFocus = FocusNode(debugLabel: 'TransDiscountFocus');
  final FocusNode customerFocus = FocusNode(debugLabel: 'CustomerFocus');

  void dispose() {
    transDiscountFocus.dispose();
    customerFocus.dispose();
  }
}

final cartTotalsFocusProvider = Provider((ref) {
  final focus = CartTotalsFocus();
  ref.onDispose(() => focus.dispose());
  return focus;
});
