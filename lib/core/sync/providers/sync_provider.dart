import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../models/sync_task.dart';
import '../services/local_database.dart';
import 'connectivity_provider.dart';

// ── Sync State ────────────────────────────────────────────────────────────

class SyncState {
  final int pendingCount;
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SyncState({
    this.pendingCount = 0,
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastError,
  });

  SyncState copyWith({
    int? pendingCount,
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearLastError = false,
  }) =>
      SyncState(
        pendingCount: pendingCount ?? this.pendingCount,
        isSyncing: isSyncing ?? this.isSyncing,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

final syncProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

class SyncNotifier extends Notifier<SyncState> {
  Box? _queueBox;
  String? _uid;
  Timer? _syncTimer;
  RealtimeChannel? _signalChannel;
  final String _sessionId = const Uuid().v4();
  bool _isFetchingDeltas = false;
  Future<Box>? _queueOpening;
  String? _queueOpeningUid;

  @override
  SyncState build() {
    final auth = ref.watch(authStateProvider).value;
    final isOnline = ref.watch(isOnlineProvider);

    _uid = auth?.uid;

    if (_uid != null) {
      _initQueue();
    } else {
      _closeQueue();
      _stopSignalListener();
    }

    if (isOnline && _uid != null) {
      _startSync();
      _startSignalListener();
    } else {
      _stopSync();
      _stopSignalListener();
    }

    ref.onDispose(() {
      _syncTimer?.cancel();
      _signalChannel?.unsubscribe();
    });

    return const SyncState();
  }

  Future<Box?> _ensureQueueBox() async {
    final uid = _uid;
    if (uid == null) return null;

    final existing = _queueBox;
    if (existing != null && existing.isOpen) return existing;

    if (_queueOpening != null && _queueOpeningUid == uid) {
      return _queueOpening;
    }

    _queueOpeningUid = uid;
    final opening = LocalDatabase.openBox(uid, 'sync_queue');
    _queueOpening = opening;
    try {
      final box = await opening;
      if (_uid == uid) {
        _queueBox = box;
        state = state.copyWith(pendingCount: box.length);
      }
      return box;
    } finally {
      if (identical(_queueOpening, opening)) {
        _queueOpening = null;
        _queueOpeningUid = null;
      }
    }
  }

  Future<void> _initQueue() async {
    await _ensureQueueBox();
  }

  void _closeQueue() {
    _queueBox?.close();
    _queueBox = null;
    state = const SyncState();
  }

  void _startSync() {
    _syncTimer?.cancel();
    _syncTimer =
        Timer.periodic(const Duration(seconds: 15), (_) => processQueue());
    Future.microtask(
      () => processQueue(retryDeferredSchemaTasks: true),
    );
  }

  void _stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void _startSignalListener() {
    if (_signalChannel != null || _uid == null) return;

    final client = ref.read(supabaseClientProvider);
    _signalChannel = client
        .channel('public:sync_metadata:$_uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sync_metadata',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: _uid!,
          ),
          callback: (payload) async {
            final data = payload.newRecord;
            if (data.isEmpty) return;

            final lastUpdateBy = data['updated_by_session'] as String?;
            if (lastUpdateBy == _sessionId) return;

            final remoteLastUpdateStr = data['last_update'] as String?;
            if (remoteLastUpdateStr == null) return;
            final remoteLastUpdate = DateTime.parse(remoteLastUpdateStr);

            final localLastSyncRaw =
                await LocalDatabase.getMetadata(_uid!, 'last_remote_sync');
            final localLastSync = localLastSyncRaw != null
                ? DateTime.parse(localLastSyncRaw as String)
                : DateTime(2000);

            if (remoteLastUpdate
                .isAfter(localLastSync.subtract(const Duration(seconds: 1)))) {
              await fetchDeltas(remoteLastUpdate);
            }
          },
        )
        .subscribe();
  }

  void _stopSignalListener() {
    _signalChannel?.unsubscribe();
    _signalChannel = null;
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> addToQueue({
    required String collection,
    required String documentId,
    required SyncAction action,
    required Map<String, dynamic> data,
  }) async {
    final task = SyncTask(
      id: const Uuid().v4(),
      collection: collection,
      documentId: documentId,
      action: action,
      data: data,
      createdAt: DateTime.now(),
    );
    await addBatchToQueue([task]);
  }

  Future<void> addBatchToQueue(List<SyncTask> tasks) async {
    if (tasks.isEmpty) return;
    final queue = await _ensureQueueBox();
    if (queue == null) return;

    final Map<dynamic, dynamic> entries = {};
    for (final task in tasks) {
      entries[task.id] = task.toMap();
    }

    await queue.putAll(entries);
    state = state.copyWith(pendingCount: queue.length);

    if (ref.read(isOnlineProvider)) {
      unawaited(processQueue());
    }
  }

  bool _isCurrentlyProcessing = false;

  Future<bool> fetchDeltas(DateTime remoteTimestamp) async {
    final uid = _uid;
    if (uid == null || _isFetchingDeltas || !ref.read(isOnlineProvider)) {
      return false;
    }

    _isFetchingDeltas = true;
    final client = ref.read(supabaseClientProvider);
    final failures = <String>[];

    try {
      final localLastSyncRaw =
          await LocalDatabase.getMetadata(uid, 'last_remote_sync');
      final localLastSync = localLastSyncRaw != null
          ? DateTime.parse(localLastSyncRaw as String)
          : DateTime(2000);
      final queryTimestamp = localLastSync.subtract(const Duration(seconds: 1));

      final pendingKeys = _queueBox?.values.map((entry) {
            final task = Map<String, dynamic>.from(entry as Map);
            return '${task['collection']}:${task['document_id']}';
          }).toSet() ??
          <String>{};

      Future<void> pullUpdatedCollection(String collection) async {
        try {
          final select = collection == 'transactions'
              ? '*, items:transaction_items(*)'
              : '*';
          final response = await client
              .from(collection)
              .select(select)
              .eq('user_id', uid)
              .gt('updated_at', queryTimestamp.toIso8601String());
          final box = await LocalDatabase.openBox(uid, collection);

          for (final row in response) {
            final data =
                LocalDatabase.sanitize(Map<String, dynamic>.from(row as Map));
            final id = data['id']?.toString();
            if (id == null || pendingKeys.contains('$collection:$id')) continue;

            final localRaw = box.get(id);
            if (localRaw != null) {
              final local = Map<String, dynamic>.from(localRaw as Map);
              final localUpdated =
                  DateTime.tryParse(local['updated_at']?.toString() ?? '') ??
                      DateTime(2000);
              final remoteUpdated =
                  DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
                      DateTime(2000);
              if (!remoteUpdated.isAfter(localUpdated)) continue;
            }
            await box.put(id, data);
          }
        } catch (error) {
          failures.add('$collection: $error');
          debugPrint('Delta Fetch Error for $collection: $error');
        }
      }

      Future<void> pullSnapshotCollection(String collection) async {
        try {
          final response =
              await client.from(collection).select().eq('user_id', uid);
          final box = await LocalDatabase.openBox(uid, collection);
          final remoteEntries = <String, Map<String, dynamic>>{};

          for (final row in response) {
            final data =
                LocalDatabase.sanitize(Map<String, dynamic>.from(row as Map));
            final id = data['id']?.toString();
            if (id != null && id.isNotEmpty) remoteEntries[id] = data;
          }

          for (final entry in remoteEntries.entries) {
            if (!pendingKeys.contains('$collection:${entry.key}')) {
              await box.put(entry.key, entry.value);
            }
          }

          // These collections have no reliable updated_at field. A full snapshot
          // is needed to observe edits and deletions from another device.
          for (final localKey in box.keys.toList()) {
            final id = localKey.toString();
            if (!remoteEntries.containsKey(id) &&
                !pendingKeys.contains('$collection:$id')) {
              await box.delete(localKey);
            }
          }
        } catch (error) {
          failures.add('$collection: $error');
          debugPrint('Snapshot Fetch Error for $collection: $error');
        }
      }

      const updatedCollections = [
        'products',
        'customers',
        'debts',
        'debt_payments',
        'transactions',
        'purchases',
      ];
      const snapshotCollections = [
        'suppliers',
        'shipping_services',
        'restock_history',
        'bill_payments',
        'barcode_history',
      ];

      await Future.wait([
        ...updatedCollections.map(pullUpdatedCollection),
        ...snapshotCollections.map(pullSnapshotCollection),
      ]);

      if (failures.isNotEmpty) {
        state = state.copyWith(
          lastError:
              'Sinkronisasi belum lengkap: ${failures.take(3).join(' | ')}',
        );
        return false;
      }

      await LocalDatabase.setMetadata(
          uid, 'last_remote_sync', remoteTimestamp.toIso8601String());
      state = state.copyWith(clearLastError: true, lastSyncAt: DateTime.now());
      return true;
    } catch (error) {
      state = state.copyWith(lastError: 'Delta sync gagal: $error');
      debugPrint('Supabase Delta Fetch Error: $error');
      return false;
    } finally {
      _isFetchingDeltas = false;
    }
  }

  Future<void> processQueue({bool retryDeferredSchemaTasks = false}) async {
    if (_isCurrentlyProcessing || !ref.read(isOnlineProvider)) return;
    final queue = await _ensureQueueBox();
    if (queue == null || queue.isEmpty) return;

    _isCurrentlyProcessing = true;
    state = state.copyWith(isSyncing: true, clearLastError: true);

    final client = ref.read(supabaseClientProvider);

    try {
      bool hasChanges = false;

      while (queue.isNotEmpty && ref.read(isOnlineProvider)) {
        final keys = <dynamic>[];
        final now = DateTime.now();
        for (final key in queue.keys) {
          final raw = queue.get(key);
          if (raw != null) {
            try {
              final task =
                  SyncTask.fromMap(Map<String, dynamic>.from(raw as Map));
              final nextRetryAt = task.nextRetryAt;
              if (!retryDeferredSchemaTasks &&
                  nextRetryAt != null &&
                  nextRetryAt.isAfter(now)) {
                continue;
              }
            } catch (_) {
              // Keep malformed entries eligible for the existing error path.
            }
          }
          keys.add(key);
          if (keys.length == 50) break;
        }
        if (keys.isEmpty) break;
        final processedKeys = <dynamic>[];
        var batchFailed = false;

        for (final key in keys) {
          final raw = queue.get(key);
          if (raw == null) {
            processedKeys.add(key);
            continue;
          }

          SyncTask? task;
          try {
            task = SyncTask.fromMap(Map<String, dynamic>.from(raw as Map));
            final table = task.collection;

            // ENSURE ID IS PRESENT (Fixes PGRST 23502)
            final Map<String, dynamic> finalData = Map.from(task.data);
            if (!finalData.containsKey('id')) {
              finalData['id'] = task.documentId;
            }
            await _prepareRemotePayload(task, finalData, client);

            switch (task.action) {
              case SyncAction.create:
              case SyncAction.update:
              case SyncAction.increment:
                try {
                  await client.from(table).upsert({
                    'user_id': _uid,
                    ...finalData,
                  });
                } catch (upsertErr) {
                  final errStr = upsertErr.toString();
                  if (isCloudSchemaNotReadyError(upsertErr)) rethrow;
                  final isSchemaOrConstraintError =
                      errStr.contains('PGRST204') ||
                          errStr.contains('schema cache') ||
                          errStr.contains('productName') ||
                          errStr.contains('23502') ||
                          errStr.contains('not-null constraint');

                  if (table == 'barcode_history' && isSchemaOrConstraintError) {
                    debugPrint(
                        'Retrying barcode_history upsert due to schema/constraint error: $errStr');

                    final pName = finalData['product_name'] ??
                        finalData['productName'] ??
                        '';
                    final pId =
                        finalData['product_id'] ?? finalData['productId'] ?? '';
                    final uAt = finalData['used_at'] ??
                        finalData['usedAt'] ??
                        DateTime.now().toIso8601String();

                    try {
                      // Attempt 1: Dual schema payload (provides both snake_case and camelCase fields)
                      await client.from(table).upsert({
                        'id': finalData['id'] ?? task.documentId,
                        'user_id': _uid,
                        'barcode': finalData['barcode'] ?? task.documentId,
                        'product_name': pName,
                        'product_id': pId,
                        'used_at': uAt,
                        'status': finalData['status'] ?? 'active',
                        'productName': pName,
                        'productId': pId,
                        'usedAt': uAt,
                      });
                    } catch (dualErr) {
                      debugPrint(
                          'Dual payload failed ($dualErr), attempting minimal barcode_history upsert');
                      try {
                        // Attempt 2: Minimal payload
                        await client.from(table).upsert({
                          'id': finalData['id'] ?? task.documentId,
                          'user_id': _uid,
                          'barcode': finalData['barcode'] ?? task.documentId,
                          'status': finalData['status'] ?? 'active',
                          'used_at': uAt,
                        });
                      } catch (minimalErr) {
                        debugPrint('Minimal upsert also failed ($minimalErr)');
                        rethrow;
                      }
                    }
                  } else {
                    rethrow;
                  }
                }
                break;
              case SyncAction.delete:
                await client
                    .from(table)
                    .delete()
                    .eq('id', task.documentId)
                    .eq('user_id', _uid!);
                break;
            }
            processedKeys.add(key);
          } catch (e) {
            final failedTask = task;
            final errStr = e.toString();
            final failureResult = failedTask == null
                ? null
                : syncTaskFailureResult(
                    failedTask,
                    e,
                    now: DateTime.now(),
                  );
            final failureDisposition = failureResult?.disposition ??
                SyncTaskFailureDisposition.discard;

            if (failureDisposition !=
                SyncTaskFailureDisposition.deferForSchema) {
              debugPrint('Sync Task Process Error for key $key: $e');
            }

            if (failedTask != null) {
              if (failureDisposition ==
                  SyncTaskFailureDisposition.deferForSchema) {
                if (!failedTask.schemaRetryLogged) {
                  debugPrint(
                    'Cloud schema is not ready for sync task '
                    '${failedTask.id} (${failedTask.collection}); '
                    'retrying in 15 minutes. Error: $errStr',
                  );
                }
                batchFailed = true;
                try {
                  await queue.put(
                    key,
                    failureResult!.task!.toMap(),
                  );
                } catch (queueError) {
                  debugPrint('Could not persist sync retry state: $queueError');
                }
                state = state.copyWith(
                  lastError: 'Sync ${failedTask.collection} ditunda: $e',
                );
              } else if (failureDisposition ==
                  SyncTaskFailureDisposition.discard) {
                debugPrint(
                    'Clearing unresolvable or max-retried sync task $key ($errStr)');
                processedKeys.add(key);
              } else {
                batchFailed = true;
                try {
                  await queue.put(key, failureResult!.task!.toMap());
                } catch (queueError) {
                  debugPrint('Could not persist sync retry state: $queueError');
                }
                state = state.copyWith(
                  lastError: 'Sync ${task?.collection ?? 'task'} gagal: $e',
                );
              }
            } else {
              processedKeys.add(key);
            }
          }
        }

        if (processedKeys.isNotEmpty) {
          await queue.deleteAll(processedKeys);
          hasChanges = true;
          state = state.copyWith(
            pendingCount: queue.length,
            lastSyncAt: DateTime.now(),
          );
        }

        // Keep failed tasks queued and wait for the next sync cycle instead of
        // immediately retrying the same schema/network failure in a tight loop.
        if (batchFailed) break;
      }

      if (hasChanges) {
        try {
          await client.from('sync_metadata').upsert({
            'user_id': _uid,
            'last_update': DateTime.now().toIso8601String(),
            'updated_by_session': _sessionId,
          });
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Sync Batch FATAL Error: $e');
      state = state.copyWith(lastError: e.toString());
    } finally {
      _isCurrentlyProcessing = false;
      state = state.copyWith(isSyncing: false);
    }
  }

  Future<void> _prepareRemotePayload(
    SyncTask task,
    Map<String, dynamic> data,
    SupabaseClient client,
  ) async {
    // 1. Keep image files strictly device-local to conserve cloud resources.
    final imagePath = data['image_path']?.toString();
    if (imagePath != null && !imagePath.startsWith('http')) {
      data.remove('image_path');
    }

    // 2. Separate relational child lists that belong to separate child tables
    if (task.collection == 'products') {
      final units = data.remove('units');
      if (units != null && units is List && units.isNotEmpty) {
        final cleanedUnits = units.map((u) {
          final m = Map<String, dynamic>.from(u as Map);
          m['product_id'] ??= task.documentId;
          m['user_id'] = _uid;
          return m;
        }).toList();
        try {
          await client.from('product_units').upsert(cleanedUnits);
        } catch (e) {
          if (isCloudSchemaNotReadyError(e)) rethrow;
          debugPrint('Product units remote sync notice: $e');
        }
      }

      final financials = data['financials'];
      if (financials != null && financials is Map) {
        data['financials'] =
            LocalDatabase.sanitize(Map<String, dynamic>.from(financials));
      }
    } else if (task.collection == 'transactions') {
      final items = data.remove('items');
      if (items != null && items is List && items.isNotEmpty) {
        final cleanedItems = items.map((i) {
          final m = Map<String, dynamic>.from(i as Map);
          m['transaction_id'] ??= task.documentId;
          m['user_id'] = _uid;
          return m;
        }).toList();
        try {
          await client.from('transaction_items').upsert(cleanedItems);
        } catch (e) {
          if (isCloudSchemaNotReadyError(e)) rethrow;
          debugPrint('Transaction items remote sync notice: $e');
        }
      }
    } else if (task.collection == 'purchases') {
      final items = data.remove('items');
      if (items != null && items is List && items.isNotEmpty) {
        final cleanedItems = items.map((i) {
          final m = Map<String, dynamic>.from(i as Map);
          m['purchase_id'] ??= task.documentId;
          m['user_id'] = _uid;
          return m;
        }).toList();
        try {
          await client.from('purchase_items').upsert(cleanedItems);
        } catch (e) {
          if (isCloudSchemaNotReadyError(e)) rethrow;
          debugPrint('Purchase items remote sync notice: $e');
        }
      }
    } else if (task.collection == 'barcode_history') {
      data['id'] ??= task.documentId;
      if (data.containsKey('productName')) {
        data['product_name'] = data.remove('productName');
      }
      if (data.containsKey('productId')) {
        data['product_id'] = data.remove('productId');
      }
      if (data.containsKey('usedAt')) {
        data['used_at'] = data.remove('usedAt');
      }
      data.remove('archivedAt');
    }
  }
}
