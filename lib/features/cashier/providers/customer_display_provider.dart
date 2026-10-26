import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import 'cart_provider.dart';

String? forcedUidForDisplay;

final customerDisplayCartProvider = StreamProvider<CartState?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final authUid = ref.watch(authStateProvider.select((a) => a.value?.uid));
  final uid = forcedUidForDisplay ?? authUid;
  
  if (uid == null) return Stream.value(null);

  final controller = StreamController<CartState?>();

  // Helper to fetch current state
  Future<void> fetch() async {
    try {
      final res = await client.from('customer_display').select().eq('user_id', uid).maybeSingle();
      if (res != null && !controller.isClosed) {
        controller.add(CartState.fromMap(res['cart_data']));
      }
    } catch (e) {
      // Quietly ignore
    }
  }

  fetch();

  final channel = client.channel('customer_display_sync')
    .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'customer_display',
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
      callback: (payload) {
        if (payload.newRecord.isNotEmpty && !controller.isClosed) {
          controller.add(CartState.fromMap(payload.newRecord['cart_data']));
        }
      },
    ).subscribe();

  ref.onDispose(() {
    channel.unsubscribe();
    controller.close();
  });

  return controller.stream;
});

class CustomerDisplayBridge {
  static Future<void> syncCart(String uid, CartState cart) async {
    try {
      final client = Supabase.instance.client;
      await client.from('customer_display').upsert({
        'user_id': uid,
        'cart_data': cart.toMap(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Quietly ignore sync errors
    }
  }
}
