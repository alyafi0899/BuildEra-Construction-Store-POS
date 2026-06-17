import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BarcodeHistoryRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Checks if a barcode was EVER used (even in deleted products)
  Future<bool> isBarcodeUsed(String barcode) async {
    if (barcode.trim().isEmpty) return false;
    
    // Check in permanent history log
    final historyDoc = await _db.collection('barcode_history').doc(barcode.trim()).get();
    if (historyDoc.exists) return true;

    // Double check in active products just in case
    final activeProducts = await _db.collection('products')
        .where('barcode', isEqualTo: barcode.trim())
        .limit(1)
        .get();
    
    return activeProducts.docs.isNotEmpty;
  }

  /// Logs a barcode into the permanent history
  Future<void> logBarcode(String barcode, String productName, String productId) async {
    if (barcode.trim().isEmpty) return;
    
    await _db.collection('barcode_history').doc(barcode.trim()).set({
      'barcode': barcode.trim(),
      'productName': productName,
      'productId': productId,
      'usedAt': FieldValue.serverTimestamp(),
      'status': 'active', // can be 'active' or 'archived' (for deleted products)
    });
  }

  /// Archives a barcode when a product is deleted
  Future<void> archiveBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return;
    
    await _db.collection('barcode_history').doc(barcode.trim()).update({
      'status': 'archived',
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }
}

final barcodeHistoryRepositoryProvider = Provider((ref) => BarcodeHistoryRepository());
