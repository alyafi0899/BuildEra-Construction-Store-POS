import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/providers/auth_provider.dart';

class BarcodeHistoryRepository {
  final String _uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  BarcodeHistoryRepository(this._uid);

  CollectionReference get _historyCol => 
      _db.collection('users').doc(_uid).collection('barcode_history');

  /// Checks if a barcode was EVER used (even in deleted products)
  Future<bool> isBarcodeUsed(String barcode) async {
    if (barcode.trim().isEmpty) return false;
    
    final historyDoc = await _historyCol.doc(barcode.trim()).get();
    if (historyDoc.exists) return true;

    final activeProducts = await _db.collection('users').doc(_uid).collection('products')
        .where('barcode', isEqualTo: barcode.trim())
        .limit(1)
        .get();
    
    return activeProducts.docs.isNotEmpty;
  }

  /// Logs a barcode into the permanent history
  Future<void> logBarcode(String barcode, String productName, String productId) async {
    if (barcode.trim().isEmpty) return;
    
    await _historyCol.doc(barcode.trim()).set({
      'barcode': barcode.trim(),
      'productName': productName,
      'productId': productId,
      'usedAt': FieldValue.serverTimestamp(),
      'status': 'active',
    });
  }

  /// Archives a barcode when a product is deleted
  Future<void> archiveBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;
    
    await _historyCol.doc(barcode.trim()).update({
      'status': 'archived',
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }
}

final barcodeHistoryRepositoryProvider = Provider<BarcodeHistoryRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return BarcodeHistoryRepository(user?.uid ?? 'unknown');
});
