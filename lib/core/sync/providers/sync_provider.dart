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
    _syncTimer = Timer.periodic(const Duration(seconds: 5), (_) => processQueue());
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
    await addBatchToQueue([
      SyncTask(
        id: const Uuid().v4(),
        collection: collection,
        documentId: documentId,
        action: action,
        data: data,
        createdAt: DateTime.now(),
      )
    ]);
  }

  Future<void> addBatchToQueue(List<SyncTask> tasks) async {
    if (_queueBox == null || tasks.isEmpty) return;

    final Map<dynamic, dynamic> entries = {};
    for (final task in tasks) {
      entries[const Uuid().v4()] = task.toMap();
    }

    await _queueBox!.putAll(entries);
    state = state.copyWith(pendingCount: _queueBox!.length);
    
    if (ref.read(isOnlineProvider)) {
      // Don't await here to avoid blocking UI during large imports
      unawaited(processQueue());
    }
  }

  Future<void> processQueue() async {
    if (state.isSyncing || _queueBox == null || _queueBox!.isEmpty || !ref.read(isOnlineProvider)) return;

    state = state.copyWith(isSyncing: true);
    
    final db = FirebaseFirestore.instance;
    final userDoc = db.collection('users').doc(_uid!);

    try {
      // Process in batches of 400 (Firestore limit is 500, we leave room for safety)
      while (_queueBox!.isNotEmpty && ref.read(isOnlineProvider)) {
        final batch = db.batch();
        final processedKeys = <dynamic>[];
        final keys = _queueBox!.keys.take(400).toList();

        for (final key in keys) {
          final raw = _queueBox!.get(key);
          if (raw == null) continue;
          
          final task = SyncTask.fromMap(raw);
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
        }

        if (processedKeys.isNotEmpty) {
          await batch.commit();
          await _queueBox!.deleteAll(processedKeys);
          state = state.copyWith(
            pendingCount: _queueBox!.length, 
            lastSyncAt: DateTime.now(), 
            lastError: null
          );
        }
      }
    } catch (e) {
      debugPrint('Sync Batch Error: $e');
      state = state.copyWith(lastError: e.toString());
    } finally {
      state = state.copyWith(isSyncing: false);
    }
  }
}
