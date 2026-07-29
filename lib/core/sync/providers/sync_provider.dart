import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    
    final db = FirebaseFirestore.instance;
    final userDoc = db.collection('users').doc(_uid!);

    try {
      // Process in smaller chunks for safety (200 is safer than 400 or 500)
      const int chunkSize = 200;

      while (_queueBox!.isNotEmpty && ref.read(isOnlineProvider)) {
        final batch = db.batch();
        final processedKeys = <dynamic>[];
        
        // Mengambil kunci antrean (keys) secara dinamis agar tidak membebani RAM
        final keys = _queueBox!.keys.take(chunkSize).toList();

        for (final key in keys) {
          final raw = _queueBox!.get(key);
          if (raw == null) {
            processedKeys.add(key);
            continue;
          }
          
          try {
            final task = SyncTask.fromMap(Map<String, dynamic>.from(raw as Map));
            final docRef = userDoc.collection(task.collection).doc(task.documentId);

            switch (task.action) {
              case SyncAction.create:
              case SyncAction.update:
                batch.set(docRef, task.data, SetOptions(merge: true));
                break;
              case SyncAction.delete:
                batch.delete(docRef);
                break;
            }
            processedKeys.add(key);
          } catch (e) {
            debugPrint('Sync Task Parse Error for key $key: $e');
            // Remove corrupted task from queue to unblock the rest
            processedKeys.add(key);
          }
        }

        if (processedKeys.isNotEmpty) {
          await batch.commit();
          // Delete from Hive ONLY after successful Firestore commit
          await _queueBox!.deleteAll(processedKeys);
          
          state = state.copyWith(
            pendingCount: _queueBox!.length, 
            lastSyncAt: DateTime.now(),
          );

          // Add a small breather to prevent CPU/Network choking on very large lists
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } catch (e) {
      debugPrint('Sync Batch FATAL Error: $e');
      state = state.copyWith(lastError: e.toString());
      
      // If it's a quota or temporary network issue, we stop and wait for the next timer pulse
    } finally {
      _isCurrentlyProcessing = false;
      state = state.copyWith(isSyncing: false);
    }
  }
}
