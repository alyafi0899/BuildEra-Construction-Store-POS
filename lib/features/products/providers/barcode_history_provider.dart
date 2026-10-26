import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';

class BarcodeHistoryRepository {
  final String _uid;
  final SupabaseClient _client;
  final Ref _ref;

  BarcodeHistoryRepository(this._uid, this._client, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'barcode_history');

  // ── Sync Logic ────────────────────────────────────────────────────────────

  Future<void> bootstrap({bool force = false}) async {
    final box = await _getBox();
    if (box.isNotEmpty && !force) return;

    final response = await _client
        .from('barcode_history')
        .select()
        .eq('user_id', _uid)
        .timeout(const Duration(seconds: 20));
    
    final Map<String, dynamic> allEntries = {};
    for (final item in response) {
      allEntries[item['id']] = LocalDatabase.sanitize(item);
    }

    if (force) await box.clear();
    
    const int chunkSize = 50;
    final keys = allEntries.keys.toList();
    for (var i = 0; i < keys.length; i += chunkSize) {
      final end = (i + chunkSize < keys.length) ? i + chunkSize : keys.length;
      final Map<String, dynamic> batch = {};
      for (var j = i; j < end; j++) {
        batch[keys[j]] = allEntries[keys[j]];
      }
      if (batch.isNotEmpty) {
        await box.putAll(batch);
      }
      await Future.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<bool> isBarcodeUsed(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return false;
    
    final box = await _getBox();
    if (box.containsKey(normalized)) return true;

    try {
      final response = await _client
          .from('barcode_history')
          .select()
          .eq('barcode', normalized)
          .eq('user_id', _uid)
          .maybeSingle()
          .timeout(const Duration(seconds: 2));
      
      if (response != null) {
        final data = LocalDatabase.sanitize(response);
        await box.put(normalized, data);
        return true;
      }
    } catch (_) {}

    return false;
  }

  Future<void> logBarcode(String barcode, String productName, String productId) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return;
    
    final data = {
      'id': normalized,
      'barcode': normalized,
      'product_name': productName,
      'product_id': productId,
      'used_at': DateTime.now().toIso8601String(),
      'status': 'active',
    };

    final box = await _getBox();
    await box.put(normalized, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'barcode_history',
      documentId: normalized,
      action:     SyncAction.update,
      data:       data,
    );
  }

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
        'id': normalized,
        'barcode': normalized,
        'product_name': item.name,
        'product_id': item.id,
        'used_at': now,
        'status': 'active',
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
  final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
  final client = ref.read(supabaseClientProvider);
  return BarcodeHistoryRepository(uid ?? 'unknown', client, ref);
});
