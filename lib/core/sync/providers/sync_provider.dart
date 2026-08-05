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
  StreamSubscription? _signalSub;

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
      _signalSub?.cancel();
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
    if (_signalSub != null || _uid == null) return;
    
    final doc = FirebaseFirestore.instance.collection('users').doc(_uid!).collection('metadata').doc('sync');
    _signalSub = doc.snapshots().listen((snap) async {
      if (!snap.exists) return;
      
      final remoteLastUpdate = (snap.data()?['last_update'] as Timestamp?)?.toDate();
      if (remoteLastUpdate == null) return;

      final localLastSyncRaw = await LocalDatabase.getMetadata(_uid!, 'last_remote_sync');
      final localLastSync = localLastSyncRaw != null ? DateTime.parse(localLastSyncRaw as String) : DateTime(2000);

      if (remoteLastUpdate.isAfter(localLastSync)) {
        await fetchDeltas(remoteLastUpdate);
      }
    });
  }

  void _stopSignalListener() {
    _signalSub?.cancel();
    _signalSub = null;
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

  Future<void> fetchDeltas(DateTime remoteTimestamp) async {
    if (_uid == null || !ref.read(isOnlineProvider)) return;

    final db = FirebaseFirestore.instance;
    final userDoc = db.collection('users').doc(_uid!);
    
    final localLastSyncRaw = await LocalDatabase.getMetadata(_uid!, 'last_remote_sync');
    final localLastSync = localLastSyncRaw != null ? DateTime.parse(localLastSyncRaw as String) : DateTime(2000);

    // List of collections to track for deltas
    final collections = ['products', 'customers', 'debts', 'debt_payments', 'transactions', 'suppliers', 'shipping_services'];

    for (final col in collections) {
      try {
        final snap = await userDoc.collection(col)
            .where('updated_at', isGreaterThan: localLastSync.toIso8601String())
            .get();

        if (snap.docs.isNotEmpty) {
          final box = await LocalDatabase.openBox(_uid!, col);
          for (final doc in snap.docs) {
            await box.put(doc.id, LocalDatabase.sanitize(doc.data()));
          }
        }
      } catch (e) {
        debugPrint('Delta Fetch Error for $col: $e');
      }
    }

    await LocalDatabase.setMetadata(_uid!, 'last_remote_sync', remoteTimestamp.toIso8601String());
  }

  Future<void> processQueue() async {
    if (_isCurrentlyProcessing || _queueBox == null || _queueBox!.isEmpty || !ref.read(isOnlineProvider)) return;

    _isCurrentlyProcessing = true;
    state = state.copyWith(isSyncing: true, lastError: null);
    
    final db = FirebaseFirestore.instance;
    final userDoc = db.collection('users').doc(_uid!);

    try {
      const int chunkSize = 200;
      bool hasChanges = false;

      while (_queueBox!.isNotEmpty && ref.read(isOnlineProvider)) {
        final batch = db.batch();
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
            final docRef = userDoc.collection(task.collection).doc(task.documentId);

            switch (task.action) {
              case SyncAction.create:
              case SyncAction.update:
                batch.set(docRef, task.data, SetOptions(merge: true));
                break;
              case SyncAction.delete:
                batch.delete(docRef);
                break;
              case SyncAction.increment:
                final incrementData = <String, dynamic>{};
                task.data.forEach((k, v) {
                  if (v is num) {
                    incrementData[k] = FieldValue.increment(v);
                  } else {
                    incrementData[k] = v;
                  }
                });
                batch.set(docRef, incrementData, SetOptions(merge: true));
                break;
            }
            processedKeys.add(key);
          } catch (e) {
            debugPrint('Sync Task Parse Error for key $key: $e');
            processedKeys.add(key);
          }
        }

        if (processedKeys.isNotEmpty) {
          await batch.commit();
          await _queueBox!.deleteAll(processedKeys);
          hasChanges = true;
          
          state = state.copyWith(
            pendingCount: _queueBox!.length, 
            lastSyncAt: DateTime.now(),
          );
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (hasChanges) {
        // Broadcast signal to other devices
        await userDoc.collection('metadata').doc('sync').set({
          'last_update': FieldValue.serverTimestamp(),
          'updated_by': _uid,
        }, SetOptions(merge: true));
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
