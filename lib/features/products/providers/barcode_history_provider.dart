import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';

class BarcodeHistoryRepository {
  final String _uid;
  final Ref _ref;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  BarcodeHistoryRepository(this._uid, this._ref);

  CollectionReference get _historyCol => 
      _db.collection('users').doc(_uid).collection('barcode_history');

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'barcode_history');

  /// Checks if a barcode was EVER used (even in deleted products)
  Future<bool> isBarcodeUsed(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return false;
    
    // 1. Check in local history log first
    final box = await _getBox();
    if (box.containsKey(normalized)) return true;

    // 2. Check in Firestore only if online
    try {
      final historyDoc = await _historyCol.doc(normalized).get().timeout(const Duration(seconds: 2));
      if (historyDoc.exists) {
        // Cache it locally if we found it on server
        await box.put(normalized, historyDoc.data());
        return true;
      }
    } catch (_) {
      // If offline or timeout, we rely on local check only
    }

    return false;
  }

  /// Logs a barcode into the permanent history
  Future<void> logBarcode(String barcode, String productName, String productId) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return;
    
    final data = {
      'barcode': normalized,
      'productName': productName,
      'productId': productId,
      'usedAt': DateTime.now().toIso8601String(),
      'status': 'active',
    };

    // 1. Save Local
    final box = await _getBox();
    await box.put(normalized, data);

    // 2. Queue Sync
    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'barcode_history',
      documentId: normalized,
      action:     SyncAction.update,
      data:       data,
    );
  }

  /// Archives a barcode when a product is deleted
  Future<void> archiveBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return;
    
    final box = await _getBox();
    final data = box.get(normalized);
    if (data != null) {
      final m = Map<String, dynamic>.from(data as Map);
      m['status'] = 'archived';
      m['archivedAt'] = DateTime.now().toIso8601String();
      await box.put(normalized, m);

      // Sync Update
      await _ref.read(syncProvider.notifier).addToQueue(
        collection: 'barcode_history',
        documentId: normalized,
        action:     SyncAction.update,
        data:       m,
      );
    }
  }
}

final barcodeHistoryRepositoryProvider = Provider<BarcodeHistoryRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return BarcodeHistoryRepository(user?.uid ?? 'unknown', ref);
});
