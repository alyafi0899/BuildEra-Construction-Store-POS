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

  @override
  SyncState build() {
    final auth = ref.watch(authStateProvider).value;
    final isOnline = ref.watch(isOnlineProvider);
    
    _uid = auth?.uid;
    
    if (_uid != null) {
      _initQueue();
    } else {
      _closeQueue();
    }

    if (isOnline && _uid != null) {
      _startSync();
    } else {
      _stopSync();
    }

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
    _syncTimer = Timer.periodic(const Duration(seconds: 10), (_) => processQueue()); // Relax timer
    // Trigger immediate process
    Future.microtask(() => processQueue());
  }

  void _stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
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
      entries[task.id] = task.toMap(); // Use task ID as key
    }

    await _queueBox!.putAll(entries);
    state = state.copyWith(pendingCount: _queueBox!.length);
    
    if (ref.read(isOnlineProvider)) {
      unawaited(processQueue());
    }
  }

  bool _isCurrentlyProcessing = false;

  Future<void> processQueue() async {
    if (_isCurrentlyProcessing || _queueBox == null || _queueBox!.isEmpty || !ref.read(isOnlineProvider)) return;

    _isCurrentlyProcessing = true;
    state = state.copyWith(isSyncing: true, lastError: null);
    
    final supabase = ref.read(supabaseClientProvider);

    try {
      const int chunkSize = 50; // Smaller chunk size for Supabase requests

      while (_queueBox!.isNotEmpty && ref.read(isOnlineProvider)) {
        final processedKeys = <dynamic>[];
        final keys = _queueBox!.keys.take(chunkSize).toList();

        for (final key in keys) {
          final raw = _queueBox!.get(key);
          if (raw == null) {
            processedKeys.add(key);
            continue;
          }
          
          try {
            final task = SyncTask.fromMap(Map<String, dynamic>.from(raw as Map));
            final data = task.data;
            data['user_id'] = _uid; // Ensure user_id is set for RLS

            switch (task.action) {
              case SyncAction.create:
              case SyncAction.update:
                await supabase.from(task.collection).upsert(data);
                break;
              case SyncAction.delete:
                await supabase.from(task.collection).delete().eq('id', task.documentId);
                break;
            }
            processedKeys.add(key);
          } catch (e) {
            debugPrint('Sync Task Parse/Request Error for key $key: $e');
            // If it's a structural error, remove it. If it's network, catch block will handle it.
            if (e.toString().contains('400') || e.toString().contains('404')) {
               processedKeys.add(key);
            } else {
               rethrow;
            }
          }
        }

        if (processedKeys.isNotEmpty) {
          await _queueBox!.deleteAll(processedKeys);
          state = state.copyWith(
            pendingCount: _queueBox!.length, 
            lastSyncAt: DateTime.now(),
          );
          await Future.delayed(const Duration(milliseconds: 200));
        }
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
