import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
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
    
    final client = supabase.Supabase.instance.client;
    
    _signalSub = client
        .from('metadata')
        .stream(primaryKey: ['user_id', 'key'])
        .eq('user_id', _uid!)
        .eq('key', 'sync')
        .listen((data) async {
      if (data.isEmpty) return;
      
      final entry = data.first;
      final lastUpdateBy = entry['updated_by_session'] as String?;
      
      // Skip if the update was made by this session to prevent circular fetch
      if (lastUpdateBy == _sessionId) return;

      final remoteLastUpdateRaw = entry['last_update'] as String?;
      if (remoteLastUpdateRaw == null) return;
      final remoteLastUpdate = DateTime.parse(remoteLastUpdateRaw);

      final localLastSyncRaw = await LocalDatabase.getMetadata(_uid!, 'last_remote_sync');
      final localLastSync = localLastSyncRaw != null ? DateTime.parse(localLastSyncRaw as String) : DateTime(2000);

      // Add a small buffer to avoid missing updates due to clock skew
      if (remoteLastUpdate.isAfter(localLastSync.subtract(const Duration(seconds: 1)))) {
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
    if (_uid == null || _isFetchingDeltas || !ref.read(isOnlineProvider)) return;

    _isFetchingDeltas = true;
    final client = supabase.Supabase.instance.client;
    
    final localLastSyncRaw = await LocalDatabase.getMetadata(_uid!, 'last_remote_sync');
    final localLastSync = localLastSyncRaw != null ? DateTime.parse(localLastSyncRaw as String) : DateTime(2000);

    final collections = ['products', 'customers', 'debts', 'debt_payments', 'transactions', 'suppliers', 'shipping_services'];

    try {
      // Fetch all deltas in parallel to improve performance
      final futures = collections.map((col) async {
        final response = await client
            .from(col)
            .select()
            .eq('user_id', _uid!)
            .gt('updated_at', localLastSync.toIso8601String());

        final List<dynamic> docs = response as List<dynamic>;

        if (docs.isNotEmpty) {
          final box = await LocalDatabase.openBox(_uid!, col);
          for (final doc in docs) {
            final data = Map<String, dynamic>.from(doc as Map);
            
            // Handle relational fields if necessary (like items in transactions)
            if (col == 'transactions') {
               final itemsRes = await client.from('transaction_items').select().eq('transaction_id', data['id']);
               data['items'] = itemsRes;
            } else if (col == 'products') {
               final unitsRes = await client.from('product_units').select().eq('product_id', data['id']);
               data['units'] = unitsRes;
            }

            await box.put(data['id'], LocalDatabase.sanitize(data));
          }
        }
      });

      await Future.wait(futures);
      await LocalDatabase.setMetadata(_uid!, 'last_remote_sync', remoteTimestamp.toIso8601String());
    } catch (e) {
      debugPrint('Parallel Delta Fetch Error: $e');
    } finally {
      _isFetchingDeltas = false;
    }
  }

  Future<void> processQueue() async {
    if (_isCurrentlyProcessing || _queueBox == null || _queueBox!.isEmpty || !ref.read(isOnlineProvider)) return;

    _isCurrentlyProcessing = true;
    state = state.copyWith(isSyncing: true, lastError: null);
    
    final client = supabase.Supabase.instance.client;

    try {
      const int chunkSize = 50; // Smaller chunks for Supabase to avoid timeout on complex increments
      bool hasChanges = false;

      while (_queueBox!.isNotEmpty && ref.read(isOnlineProvider)) {
        final keys = _queueBox!.keys.take(chunkSize).toList();
        final processedKeys = <dynamic>[];

        for (final key in keys) {
          final raw = _queueBox!.get(key);
          if (raw == null) {
            processedKeys.add(key);
            continue;
          }
          
          try {
            final task = SyncTask.fromMap(Map<String, dynamic>.from(raw as Map));
            final data = Map<String, dynamic>.from(task.data);
            
            // Inject user_id into all data
            data['user_id'] = _uid;

            switch (task.action) {
              case SyncAction.create:
                // Handle nested items for transactions/products
                if (task.collection == 'transactions' && data.containsKey('items')) {
                   final items = (data.remove('items') as List);
                   await client.from('transactions').insert(data);
                   await client.from('transaction_items').insert(items);
                } else if (task.collection == 'products' && data.containsKey('units')) {
                   final units = (data.remove('units') as List);
                   await client.from('products').insert(data);
                   await client.from('product_units').insert(units);
                } else {
                   await client.from(task.collection).insert(data);
                }
                break;
                
              case SyncAction.update:
                if (task.collection == 'transactions' && data.containsKey('items')) {
                   final items = (data.remove('items') as List);
                   await client.from('transactions').update(data).eq('id', task.documentId);
                   // For items, we usually replace them
                   await client.from('transaction_items').delete().eq('transaction_id', task.documentId);
                   await client.from('transaction_items').insert(items);
                } else if (task.collection == 'products' && data.containsKey('units')) {
                   final units = (data.remove('units') as List);
                   await client.from('products').update(data).eq('id', task.documentId);
                   await client.from('product_units').delete().eq('product_id', task.documentId);
                   await client.from('product_units').insert(units);
                } else {
                   await client.from(task.collection).update(data).eq('id', task.documentId);
                }
                break;
                
              case SyncAction.delete:
                await client.from(task.collection).delete().eq('id', task.documentId);
                break;
                
              case SyncAction.increment:
                // ATOMIC INCREMENT logic using PostgreSQL SQL fragment via RPC or custom query
                // We use a simple UPDATE ... SET col = col + val
                final updates = <String, String>{};
                final staticData = <String, dynamic>{};
                
                task.data.forEach((k, v) {
                  if (v is num) {
                    updates[k] = v.toString();
                  } else {
                    staticData[k] = v;
                  }
                });

                if (updates.isNotEmpty) {
                  // Build a SQL-like update for increments
                  // Note: Supabase postgrest doesn't have a direct 'increment' method in the dart client yet
                  // but we can use a small RPC helper or a raw query if enabled.
                  // For now, we'll use a safer approach: RPC 'increment_column'
                  for (final entry in updates.entries) {
                    await client.rpc('increment_column', params: {
                      't_name': task.collection,
                      'c_name': entry.key,
                      'row_id': task.documentId,
                      'delta': double.parse(entry.value),
                    });
                  }
                }
                
                if (staticData.isNotEmpty) {
                  await client.from(task.collection).update(staticData).eq('id', task.documentId);
                }
                break;
            }
            processedKeys.add(key);
          } catch (e) {
            debugPrint('Sync Task Execute Error for key $key: $e');
            // If it's a permanent error (e.g. invalid data), we might want to skip it
            // For now, we'll keep retrying by not adding to processedKeys if it's a network error
            if (e.toString().contains('network') || e.toString().contains('SocketException')) {
               break; // Stop processing this chunk and wait for next pulse
            }
            processedKeys.add(key); // Permanent error, skip task
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
        // Broadcast signal to other devices
        await client.from('metadata').upsert({
          'user_id': _uid,
          'key': 'sync',
          'last_update': DateTime.now().toIso8601String(),
          'updated_by_session': _sessionId,
        });
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
