import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cart_provider.dart';

class MultiCartState {
  final List<CartState> carts;
  final int activeIndex;

  const MultiCartState({
    required this.carts,
    required this.activeIndex,
  });

  MultiCartState copyWith({
    List<CartState>? carts,
    int? activeIndex,
  }) {
    return MultiCartState(
      carts: carts ?? this.carts,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

class MultiCartNotifier extends Notifier<MultiCartState> {
  @override
  MultiCartState build() {
    // Default with 1 empty cart (tab)
    return const MultiCartState(
      carts: [
        CartState(),
      ],
      activeIndex: 0,
    );
  }

  void switchCart(int newIndex) {
    if (newIndex == state.activeIndex) return;
    if (newIndex < 0 || newIndex >= state.carts.length) return;

    // 1. Save current active cart to the list
    final currentCart = ref.read(cartProvider);
    final updatedCarts = List<CartState>.from(state.carts);
    updatedCarts[state.activeIndex] = currentCart;

    // 2. Load the new cart to the cartProvider
    final newCart = updatedCarts[newIndex];
    ref.read(cartProvider.notifier).stateValue = newCart;

    // 3. Update MultiCartState
    state = state.copyWith(
      carts: updatedCarts,
      activeIndex: newIndex,
    );
  }
  
  void addNewCart() {
    if (state.carts.length >= 8) return; // Limit to 8 carts
    state = state.copyWith(
      carts: [...state.carts, const CartState()],
    );
  }
  
  void removeCart(int index) {
    if (state.carts.length <= 1) return; // Must have at least one cart
    
    final updatedCarts = List<CartState>.from(state.carts);
    
    // If we are removing the active cart, we need to switch first
    if (index == state.activeIndex) {
      final targetIndex = index == 0 ? 1 : index - 1;
      switchCart(targetIndex);
      
      // After switching, the list in state is updated, so re-get it
      final listAfterSwitch = List<CartState>.from(state.carts);
      listAfterSwitch.removeAt(index);
      
      // Calculate new active index after removal
      int newActive = state.activeIndex;
      if (index <= state.activeIndex) {
         newActive = (state.activeIndex - 1).clamp(0, listAfterSwitch.length - 1);
      }
      
      state = state.copyWith(carts: listAfterSwitch, activeIndex: newActive);
    } else {
      updatedCarts.removeAt(index);
      int newActive = state.activeIndex;
      if (index < state.activeIndex) {
        newActive--;
      }
      state = state.copyWith(carts: updatedCarts, activeIndex: newActive);
    }
  }
}

final multiCartProvider = NotifierProvider<MultiCartNotifier, MultiCartState>(MultiCartNotifier.new);
