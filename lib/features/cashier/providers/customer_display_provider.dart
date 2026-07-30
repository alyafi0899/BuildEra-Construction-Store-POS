import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import 'cart_provider.dart';

/// Global variable to store the UID when launched as a secondary process.
String? forcedUidForDisplay;

/// This provider is used by the customer display to listen to the "live" cart from Supabase.
final customerDisplayCartProvider = StreamProvider<CartState?>((ref) {
  final user = ref.watch(authStateProvider).value;
  final uid = forcedUidForDisplay ?? user?.uid;
  final supabase = ref.watch(supabaseClientProvider);
  
  if (uid == null) return Stream.value(null);

  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((data) {
        if (data.isEmpty) return const CartState();
        final displayData = data.first['customer_display'];
        if (displayData == null) return const CartState();
        return CartState.fromMap(Map<String, dynamic>.from(displayData));
      });
});

class CustomerDisplayBridge {
  /// Writes the current cart state to Supabase for the customer display to pick up.
  static Future<void> syncCart(SupabaseClient supabase, String uid, CartState cart) async {
    try {
      await supabase.from('profiles').update({
        'customer_display': cart.toMap(),
      }).eq('id', uid);
    } catch (e) {
      // Quietly ignore sync errors
    }
  }
}
