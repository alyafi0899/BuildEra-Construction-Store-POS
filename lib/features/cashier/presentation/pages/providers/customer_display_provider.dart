import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import 'cart_provider.dart';

/// Global variable to store the UID when launched as a secondary process.
String? forcedUidForDisplay;

/// This provider is used by the customer display to listen to the "live" cart from Firestore.
final customerDisplayCartProvider = StreamProvider<CartState?>((ref) {
  final user = ref.watch(authStateProvider).value;
  final uid = forcedUidForDisplay ?? user?.uid;
  
  if (uid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('metadata')
      .doc('customer_display')
      .snapshots()
      .map((doc) {
        if (!doc.exists) return const CartState();
        return CartState.fromMap(doc.data()!);
      });
});

class CustomerDisplayBridge {
  /// Writes the current cart state to Firestore for the customer display to pick up.
  static Future<void> syncCart(String uid, CartState cart) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('metadata')
          .doc('customer_display')
          .set(cart.toMap());
    } catch (e) {
      // Quietly ignore sync errors
    }
  }
}
