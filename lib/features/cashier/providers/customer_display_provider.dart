import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import 'cart_provider.dart';

/// Global variable to store the UID when launched as a secondary process.
String? forcedUidForDisplay;

/// This provider is used by the customer display to listen to the "live" cart from Supabase.
final customerDisplayCartProvider = StreamProvider<CartState?>((ref) {
  final user = ref.watch(authStateProvider).value;
  final uid = forcedUidForDisplay ?? user?.uid;
  
  if (uid == null) return Stream.value(null);

  final client = supabase.Supabase.instance.client;
  
  // Create a stream for the metadata table where key = 'customer_display'
  return client
      .from('metadata')
      .stream(primaryKey: ['user_id', 'key'])
      .eq('user_id', uid)
      .eq('key', 'customer_display')
      .map((data) {
        if (data.isEmpty) return const CartState();
        final json = data.first['value'];
        if (json == null) return const CartState();
        return CartState.fromMap(Map<String, dynamic>.from(json as Map));
      });
});

class CustomerDisplayBridge {
  /// Writes the current cart state to Supabase for the customer display to pick up.
  static Future<void> syncCart(String uid, CartState cart) async {
    try {
      final client = supabase.Supabase.instance.client;
      await client.from('metadata').upsert({
        'user_id': uid,
        'key': 'customer_display',
        'value': cart.toMap(),
        'last_update': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Quietly ignore sync errors
    }
  }
}
