import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'cart_provider.dart';

/// Use Notifier instead of StateProvider for better compatibility across versions
final customerCartProvider = NotifierProvider<CustomerCartNotifier, CartState>(CustomerCartNotifier.new);

class CustomerCartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    return const CartState();
  }

  void updateState(CartState newState) {
    state = newState;
  }
}

class CustomerDisplayBridge {
  static void init(WidgetRef ref) {
    DesktopMultiWindow.setMethodHandler((MethodCall call, int fromWindowId) async {
      if (call.method == 'updateCart') {
        final Map<String, dynamic> data = json.decode(call.arguments as String);
        ref.read(customerCartProvider.notifier).updateState(CartState.fromMap(data));
      }
      return null;
    });
  }

  /// Broadcasts the current cart state to all other windows.
  static void broadcastCart(CartState state) async {
    try {
      final jsonStr = json.encode(state.toMap());
      final subWindowIds = await DesktopMultiWindow.getAllSubWindowIds();
      for (final id in subWindowIds) {
        DesktopMultiWindow.invokeMethod(id, 'updateCart', jsonStr);
      }
    } catch (e) {
      // Ignore errors if no other windows are open
    }
  }
}
