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
    this.isSyncing    = false,
    this.lastSyncAt,
    this.lastError,
  });

  SyncState copyWith({
    int? pendingCount,
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? lastError,
  }) =>
      SyncState(
        pendingCount: pendingCount ?? this.pendingCount,
        isSyncing:    isSyncing    ?? this.isSyncing,
        lastSyncAt:   lastSyncAt   ?? this.lastSyncAt,
        lastError:    lastError    ?? this.lastError,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────

final syncProvider = NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

class SyncNotifier extends Notifier<SyncState> {
  Box? _queueBox;
  String? _uid;
  Timer? _syncTimer;
  RealtimeChannel? _signalChannel;
  final String _sessionId = const Uuid().v4();
  bool _isFetchingDeltas = false;

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

  Future<void> _initQueue() async {
    _queueBox = await LocalDatabase.openBox(_uid!, 'sync_queue');
    state = state.copyWith(pendingCount: _queueBox!.length);
  }

  void _closeQueue() {
    _queueBox?.close();
    _queueBox = null;
    state = const SyncState();
  }

  void _startSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) => processQueue());
    Future.microtask(() => processQueue());
  }

  void _stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void _startSignalListener() {
    if (_signalChannel != null || _uid == null) return;
    
    final client = ref.read(supabaseClientProvider);
    _signalChannel = client.channel('public:sync_metadata:$_uid')
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

          final localLastSyncRaw = await LocalDatabase.getMetadata(_uid!, 'last_remote_sync');
          final localLastSync = localLastSyncRaw != null ? DateTime.parse(localLastSyncRaw as String) : DateTime(2000);

          if (remoteLastUpdate.isAfter(localLastSync.subtract(const Duration(seconds: 1)))) {
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
    if (_queueBox == null || tasks.isEmpty) return;

    final Map<dynamic, dynamic> entries = {};
    for (final task in tasks) {
      entries[task.id] = task.toMap();
    }

    await _queueBox!.putAll(entries);
    state = state.copyWith(pendingCount: _queueBox!.length);
    
    if (ref.read(isOnlineProvider)) {
      unawaited(processQueue());
    }
  }

  bool _isCurrentlyProcessing = false;

  Future<void> fetchDeltas(DateTime remoteTimestamp) async {
    if (_uid == null || _isFetchingDeltas || !ref.read(isOnlineProvider)) return;

    _isFetchingDeltas = true;
    final client = ref.read(supabaseClientProvider);
    
    final localLastSyncRaw = await LocalDatabase.getMetadata(_uid!, 'last_remote_sync');
    final localLastSync = localLastSyncRaw != null ? DateTime.parse(localLastSyncRaw as String) : DateTime(2000);

    final collections = ['products', 'customers', 'debts', 'debt_payments', 'transactions', 'purchases'];
    final queryTimestamp = localLastSync.subtract(const Duration(seconds: 1));

    final pendingIds = _queueBox?.values
        .map((e) => Map<String, dynamic>.from(e as Map)['document_id'] as String)
        .toSet() ?? {};

    try {
      final futures = collections.map((col) async {
        try {
          final List<dynamic> response = await client
              .from(col)
              .select()
              .eq('user_id', _uid!)
              .gt('updated_at', queryTimestamp.toIso8601String());

          if (response.isNotEmpty) {
            final box = await LocalDatabase.openBox(_uid!, col);
            
            for (final item in response) {
              final data = LocalDatabase.sanitize(item as Map<String, dynamic>);
              final id = data['id'] as String?;

              if (id == null || pendingIds.contains(id)) continue;

              final localDataRaw = box.get(id);
              if (localDataRaw != null) {
                final localData = Map<String, dynamic>.from(localDataRaw as Map);
                final localUpdatedStr = localData['updated_at'] as String?;
                final remoteUpdatedStr = data['updated_at'] as String?;

                if (localUpdatedStr != null && remoteUpdatedStr != null) {
                  final localUpdated = DateTime.tryParse(localUpdatedStr) ?? DateTime(2000);
                  final remoteUpdated = DateTime.tryParse(remoteUpdatedStr) ?? DateTime(2000);

                  if (localUpdated.isAfter(remoteUpdated) || localUpdated.isAtSameMomentAs(remoteUpdated)) {
                    continue;
                  }
                }
              }
              await box.put(id, data);
            }
          }
        } catch (e) {
          // Table might not exist yet, skip
          debugPrint('Delta Fetch Error for $col: $e');
        }
      });

      await Future.wait(futures);
      await LocalDatabase.setMetadata(_uid!, 'last_remote_sync', remoteTimestamp.toIso8601String());
    } catch (e) {
      debugPrint('Supabase Delta Fetch Error: $e');
    } finally {
      _isFetchingDeltas = false;
    }
  }

  Future<void> processQueue() async {
    if (_isCurrentlyProcessing || _queueBox == null || _queueBox!.isEmpty || !ref.read(isOnlineProvider)) return;

    _isCurrentlyProcessing = true;
    state = state.copyWith(isSyncing: true, lastError: null);
    
    final client = ref.read(supabaseClientProvider);

    try {
      bool hasChanges = false;

      while (_queueBox!.isNotEmpty && ref.read(isOnlineProvider)) {
        final keys = _queueBox!.keys.take(50).toList();
        final processedKeys = <dynamic>[];

        for (final key in keys) {
          final raw = _queueBox!.get(key);
          if (raw == null) {
            processedKeys.add(key);
            continue;
          }
          
          try {
            final task = SyncTask.fromMap(Map<String, dynamic>.from(raw as Map));
            final table = task.collection;

            // ENSURE ID IS PRESENT (Fixes PGRST 23502)
            final Map<String, dynamic> finalData = Map.from(task.data);
            if (!finalData.containsKey('id')) {
              finalData['id'] = task.documentId;
            }

            switch (task.action) {
              case SyncAction.create:
                await client.from(table).upsert({
                  'user_id': _uid,
                  ...finalData,
                });
                break;
              case SyncAction.update:
              case SyncAction.increment:
                // Use update() instead of upsert() for partial updates/increments
                // to avoid NOT NULL constraint errors if the record doesn't exist yet.
                await client.from(table).update({
                  ...finalData,
                }).eq('id', task.documentId).eq('user_id', _uid!);
                break;
              case SyncAction.delete:
                await client.from(table).delete().eq('id', task.documentId).eq('user_id', _uid!);
                break;
            }
            processedKeys.add(key);
          } catch (e) {
            debugPrint('Sync Task Process Error for key $key: $e');
            // Discared if it's a structural error (column not found) to prevent infinite loop
            if (e.toString().contains('PGRST204') || e.toString().contains('PGRST205')) {
               processedKeys.add(key);
            }
            // Discard if it's a foreign key error for now, until full sync is re-run
            if (e.toString().contains('23503')) {
               processedKeys.add(key);
            }
          }
        }

        if (processedKeys.isNotEmpty) {
          await _queueBox!.deleteAll(processedKeys);
          hasChanges = true;
          state = state.copyWith(
            pendingCount: _queueBox!.length, 
            lastSyncAt: DateTime.now(),
          );
        }
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
}
