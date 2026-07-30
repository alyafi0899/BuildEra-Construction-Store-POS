import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';

class BarcodeHistoryRepository {
  final String _uid;
  final SupabaseClient _supabase;
  final Ref _ref;

  BarcodeHistoryRepository(this._uid, this._supabase, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'barcode_history');

  // ── Sync Logic ────────────────────────────────────────────────────────────

  Future<void> bootstrap({bool force = false}) async {
    final box = await _getBox();
    if (box.isNotEmpty && !force) return;

    final response = await _supabase.from('barcode_history').select().eq('user_id', _uid);
    if (force) await box.clear();
    for (final data in response) {
      await box.put(data['barcode'], LocalDatabase.sanitize(data));
    }
  }

  /// Checks if a barcode was EVER used (even in deleted products)
  Future<bool> isBarcodeUsed(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return false;
    
    // 1. Check in local history log first
    final box = await _getBox();
    if (box.containsKey(normalized)) return true;

    // 2. Check in Supabase only if online
    try {
      final response = await _supabase.from('barcode_history').select().eq('barcode', normalized).maybeSingle();
      if (response != null) {
        // Cache it locally if we found it on server
        final data = LocalDatabase.sanitize(response);
        await box.put(normalized, data);
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
      'user_id': _uid,
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

  /// Logs multiple barcodes into the permanent history in a single batch
  Future<void> logBarcodesBatch(List<({String barcode, String name, String id})> items) async {
    if (items.isEmpty) return;
    
    final box = await _getBox();
    final tasks = <SyncTask>[];
    final now = DateTime.now().toIso8601String();
    final Map<String, dynamic> localEntries = {};

    for (final item in items) {
      final normalized = item.barcode.trim();
      if (normalized.isEmpty) continue;

      final data = {
        'barcode': normalized,
        'productName': item.name,
        'productId': item.id,
        'usedAt': now,
        'status': 'active',
        'user_id': _uid,
      };

      localEntries[normalized] = data;
      
      tasks.add(SyncTask(
        id: const Uuid().v4(),
        collection: 'barcode_history',
        documentId: normalized,
        action:     SyncAction.update,
        data:       data,
        createdAt: DateTime.now(),
      ));
    }

    if (localEntries.isNotEmpty) {
      await box.putAll(localEntries);
      await _ref.read(syncProvider.notifier).addBatchToQueue(tasks);
    }
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
      m['user_id'] = _uid;
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
  final supabase = ref.watch(supabaseClientProvider);
  return BarcodeHistoryRepository(user?.uid ?? 'unknown', supabase, ref);
});
