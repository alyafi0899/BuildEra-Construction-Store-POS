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
  final int deadLetterCount;
  final bool isSyncing;
  final DateTime? lastSyncAt;
  final String? lastError;

  const SyncState({
    this.pendingCount = 0,
    this.deadLetterCount = 0,
    this.isSyncing = false,
    this.lastSyncAt,
    this.lastError,
  });

  SyncState copyWith({
    int? pendingCount,
    int? deadLetterCount,
    bool? isSyncing,
    DateTime? lastSyncAt,
    String? lastError,
    bool clearLastError = false,
  }) =>
      SyncState(
        pendingCount: pendingCount ?? this.pendingCount,
        deadLetterCount: deadLetterCount ?? this.deadLetterCount,
        isSyncing: isSyncing ?? this.isSyncing,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        lastError: clearLastError ? null : (lastError ?? this.lastError),
      );
}

/// Koleksi yang ditarik secara delta (updated_at) + tombstone untuk delete.
const _updatedCollections = [
  'products',
  'customers',
  'debts',
  'debt_payments',
  'transactions',
  'purchases',
];

/// Koleksi tanpa updated_at yang andal: ditarik sebagai snapshot penuh.
const _snapshotCollections = [
  'suppliers',
  'shipping_services',
  'restock_history',
  'bill_payments',
  'barcode_history',
];

/// Task yang gagal permanen (RLS/skema/validasi) dipindah ke dead-letter
/// setelah sejumlah percobaan agar tidak memblokir antrean selamanya.
const _maxRetries = 5;

// ── Notifier ──────────────────────────────────────────────────────────────

final syncProvider =
    NotifierProvider<SyncNotifier, SyncState>(SyncNotifier.new);

class SyncNotifier extends Notifier<SyncState> {
  Box? _queueBox;
  String? _queueBoxUid;
  Future<Box>? _queueOpening;
  String? _queueOpeningUid;

  String? _uid;
  Timer? _syncTimer;
  int _tick = 0;

  RealtimeChannel? _signalChannel;
  String? _signalUid;
  Timer? _signalRetry;

  final String _sessionId = const Uuid().v4();
  bool _isFetchingDeltas = false;
  bool _refetchRequested = false;
  bool _isCurrentlyProcessing = false;
  bool _metaDirty = false;
  int _lastSeq = 0;

  @override
  SyncState build() {
    // select(): hanya rebuild saat uid berubah, bukan tiap token refresh.
    final uid = ref.watch(authStateProvider.select((a) => a.value?.uid));
    final isOnline = ref.watch(isOnlineProvider);

    if (uid != _uid) {
      _stopSignalListener();
      _closeQueue();
    }
    _uid = uid;

    if (uid != null) {
      unawaited(_ensureQueueBox());
    }

    if (isOnline && uid != null) {
      _startSync();
      _startSignalListener();
    } else {
      _stopSync();
      _stopSignalListener();
    }

    ref.onDispose(() {
      _syncTimer?.cancel();
      _syncTimer = null;
      _stopSignalListener();
    });

    return const SyncState();
  }

  // ── Queue box ────────────────────────────────────────────────────────────

  Future<Box?> _ensureQueueBox() async {
    final uid = _uid;
    if (uid == null) return null;

    final existing = _queueBox;
    if (existing != null && existing.isOpen && _queueBoxUid == uid) {
      return existing;
    }

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
        _queueBoxUid = uid;
        final dead = await LocalDatabase.openBox(uid, 'sync_dead_letter');
        state = state.copyWith(
            pendingCount: box.length, deadLetterCount: dead.length);
      }
      return box;
    } finally {
      if (identical(_queueOpening, opening)) {
        _queueOpening = null;
        _queueOpeningUid = null;
      }
    }
  }

  void _closeQueue() {
    final box = _queueBox;
    _queueBox = null;
    _queueBoxUid = null;
    if (box != null && box.isOpen) {
      unawaited(box.close());
    }
  }

  void _startSync() {
    _syncTimer?.cancel();
    _tick = 0;
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _tick++;
      unawaited(processQueue());
      // Fallback: kalau sinyal realtime terlewat, tarik perubahan tiap ~60 dtk.
      if (_tick % 4 == 0) unawaited(fetchDeltas());
      if (_metaDirty) unawaited(_signalOthers());
    });
    Future.microtask(() async {
      await processQueue();
      await fetchDeltas(); // kejar perubahan yang terlewat saat offline/mati
    });
  }

  void _stopSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  // ── Realtime signal ─────────────────────────────────────────────────────

  void _startSignalListener() {
    final uid = _uid;
    if (uid == null) return;
    if (_signalChannel != null && _signalUid == uid) return;
    _stopSignalListener();

    _signalUid = uid;
    final client = ref.read(supabaseClientProvider);
    _signalChannel = client
        .channel('public:sync_metadata:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sync_metadata',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            final data = payload.newRecord;
            if (data.isEmpty) return;
            if (data['updated_by_session'] == _sessionId) return;
            // Jam device lain tidak dipercaya: cukup tarik delta dari checkpoint.
            unawaited(fetchDeltas());
          },
        )
        .subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(fetchDeltas()); // kejar sinyal yang terlewat saat putus
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut) {
        debugPrint('Sync signal channel $status: $error');
        _stopSignalListener();
        _signalRetry?.cancel();
        _signalRetry = Timer(const Duration(seconds: 10), () {
          if (_uid != null && ref.read(isOnlineProvider)) {
            _startSignalListener();
          }
        });
      }
    });
  }

  void _stopSignalListener() {
    _signalRetry?.cancel();
    _signalRetry = null;
    _signalChannel?.unsubscribe();
    _signalChannel = null;
    _signalUid = null;
  }

  Future<void> _signalOthers() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await ref.read(supabaseClientProvider).from('sync_metadata').upsert({
        'user_id': uid,
        'last_update': DateTime.now().toUtc().toIso8601String(),
        'updated_by_session': _sessionId,
      });
      _metaDirty = false;
    } catch (e) {
      // Tidak fatal (ada polling cadangan), tapi dicoba lagi di tick berikutnya.
      _metaDirty = true;
      debugPrint('sync_metadata signal failed: $e');
    }
  }

  // ── Enqueue ─────────────────────────────────────────────────────────────

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

    final entries = <dynamic, dynamic>{};
    for (final task in tasks) {
      // Urutan antrean ditentukan (createdAt, seq), BUKAN urutan key Hive
      // (key string di Hive terurut leksikografis, jadi UUID acak).
      final now = DateTime.now().microsecondsSinceEpoch;
      _lastSeq = now > _lastSeq ? now : _lastSeq + 1;
      entries[task.id] = task.copyWith(seq: _lastSeq).toMap();
    }

    await queue.putAll(entries);
    state = state.copyWith(pendingCount: queue.length);

    if (ref.read(isOnlineProvider)) {
      unawaited(processQueue());
    }
  }

  // ── Pull (delta) ────────────────────────────────────────────────────────

  Set<String> _pendingDocKeys() {
    final queue = _queueBox;
    if (queue == null || !queue.isOpen) return <String>{};
    final keys = <String>{};
    for (final raw in queue.values) {
      final m = raw as Map;
      keys.add('${m['collection']}:${m['document_id']}');
    }
    return keys;
  }

  /// [hint] dipertahankan demi kompatibilitas pemanggil lama; tidak dipakai.
  /// Checkpoint kini = updated_at terbesar dari SERVER yang sudah diterapkan.
  Future<bool> fetchDeltas([DateTime? hint]) async {
    final uid = _uid;
    if (uid == null || !ref.read(isOnlineProvider)) return false;
    if (_isFetchingDeltas) {
      _refetchRequested = true; // jangan buang sinyal yang datang saat fetch
      return false;
    }

    _isFetchingDeltas = true;
    var ok = false;
    try {
      ok = await _pullOnce(uid);
    } catch (error) {
      state = state.copyWith(lastError: 'Delta sync gagal: $error');
      debugPrint('Supabase Delta Fetch Error: $error');
    } finally {
      _isFetchingDeltas = false;
    }

    if (_refetchRequested) {
      _refetchRequested = false;
      unawaited(fetchDeltas());
    }
    return ok;
  }

  Future<bool> _pullOnce(String uid) async {
    final client = ref.read(supabaseClientProvider);

    // Jangan tarik apa pun sebelum unduhan awal selesai (tampil di AuthGate).
    final syncMeta = await LocalDatabase.openBox(uid, 'sync_meta');
    if (syncMeta.get('initial_sync_done') != true) return false;

    final raw = await LocalDatabase.getMetadata(uid, 'last_remote_sync');
    final checkpoint = raw != null
        ? DateTime.parse(raw as String).toUtc()
        : DateTime.utc(2000);
    // Overlap 2 detik: transaksi yang commit terlambat tetap tertangkap.
    final lowerIso =
        checkpoint.subtract(const Duration(seconds: 2)).toIso8601String();

    var maxSeen = checkpoint;
    final failures = <String>[];
    final updatedStamps = <String, DateTime>{}; // 'koleksi:id' -> updated_at

    Future<void> pullUpdated(String collection) async {
      try {
        final select = collection == 'transactions'
            ? '*, items:transaction_items(*)'
            : '*';
        final response = await client
            .from(collection)
            .select(select)
            .eq('user_id', uid)
            .gt('updated_at', lowerIso);

        final box = await LocalDatabase.openBox(uid, collection);
        final pending = _pendingDocKeys(); // dihitung SETELAH network selesai
        final batch = <String, dynamic>{};

        for (final row in response) {
          final data =
              LocalDatabase.sanitize(Map<String, dynamic>.from(row as Map));
          final id = data['id']?.toString();
          if (id == null) continue;

          final ts = DateTime.tryParse(data['updated_at']?.toString() ?? '')
              ?.toUtc();
          if (ts != null) {
            updatedStamps['$collection:$id'] = ts;
            if (ts.isAfter(maxSeen)) maxSeen = ts;
          }
          // Perubahan lokal yang belum terkirim menang (akan di-push & LWW di server).
          if (pending.contains('$collection:$id')) continue;
          batch[id] = data;
        }
        if (batch.isNotEmpty) await box.putAll(batch);
      } catch (error) {
        failures.add('$collection: $error');
        debugPrint('Delta Fetch Error for $collection: $error');
      }
    }

    Future<void> pullSnapshot(String collection) async {
      try {
        final response =
            await client.from(collection).select().eq('user_id', uid);
        final box = await LocalDatabase.openBox(uid, collection);
        final pending = _pendingDocKeys();
        final remote = <String, Map<String, dynamic>>{};

        for (final row in response) {
          final data =
              LocalDatabase.sanitize(Map<String, dynamic>.from(row as Map));
          final id = data['id']?.toString();
          if (id != null && id.isNotEmpty) remote[id] = data;
        }

        final batch = <String, dynamic>{};
        for (final e in remote.entries) {
          if (!pending.contains('$collection:${e.key}')) batch[e.key] = e.value;
        }
        if (batch.isNotEmpty) await box.putAll(batch);

        for (final localKey in box.keys.toList()) {
          final id = localKey.toString();
          if (!remote.containsKey(id) && !pending.contains('$collection:$id')) {
            await box.delete(localKey);
          }
        }
      } catch (error) {
        failures.add('$collection: $error');
        debugPrint('Snapshot Fetch Error for $collection: $error');
      }
    }

    await Future.wait([
      ..._updatedCollections.map(pullUpdated),
      ..._snapshotCollections.map(pullSnapshot),
    ]);

    // Delete dari device lain (tombstone dicatat trigger di server).
    try {
      final tombs = await client
          .from('sync_tombstones')
          .select('collection, doc_id, deleted_at')
          .eq('user_id', uid)
          .gt('deleted_at', lowerIso);
      final pending = _pendingDocKeys();

      for (final t in tombs) {
        final col = t['collection']?.toString();
        final id = t['doc_id']?.toString();
        final del = DateTime.tryParse(t['deleted_at']?.toString() ?? '')?.toUtc();
        if (col == null || id == null || !_updatedCollections.contains(col)) {
          continue;
        }
        if (del != null && del.isAfter(maxSeen)) maxSeen = del;

        final key = '$col:$id';
        if (pending.contains(key)) continue;
        final upd = updatedStamps[key];
        if (upd != null && del != null && upd.isAfter(del)) continue; // dibuat ulang

        final box = await LocalDatabase.openBox(uid, col);
        if (box.containsKey(id)) await box.delete(id);
      }
    } on PostgrestException catch (e) {
      // Migrasi belum diterapkan: jangan melumpuhkan seluruh sync.
      if (e.code == '42P01' || e.code == 'PGRST205') {
        debugPrint('sync_tombstones belum ada — jalankan migrasi sync_hardening.');
      } else {
        failures.add('tombstones: ${e.message}');
      }
    } catch (error) {
      failures.add('tombstones: $error');
    }

    if (failures.isNotEmpty) {
      // Checkpoint TIDAK maju agar tidak ada data yang terlewat.
      state = state.copyWith(
        lastError: 'Sinkronisasi belum lengkap: ${failures.take(3).join(' | ')}',
      );
      return false;
    }

    await LocalDatabase.setMetadata(
        uid, 'last_remote_sync', maxSeen.toUtc().toIso8601String());
    state = state.copyWith(clearLastError: true, lastSyncAt: DateTime.now());
    return true;
  }

  // ── Push (queue) ────────────────────────────────────────────────────────

  List<MapEntry<dynamic, SyncTask>> _sortedEntries(Box queue) {
    final out = <MapEntry<dynamic, SyncTask>>[];
    for (final key in queue.keys.toList()) {
      final raw = queue.get(key);
      if (raw == null) continue;
      try {
        out.add(MapEntry(
            key, SyncTask.fromMap(Map<String, dynamic>.from(raw as Map))));
      } catch (e) {
        debugPrint('Dropping corrupt sync task $key: $e');
        unawaited(queue.delete(key));
      }
    }
    out.sort((a, b) {
      final c = a.value.createdAt.compareTo(b.value.createdAt);
      return c != 0 ? c : a.value.seq.compareTo(b.value.seq);
    });
    return out;
  }

  /// Gangguan jaringan / server sementara → tunda semua, jangan hitung retry.
  bool _isTransient(PostgrestException e) {
    final code = e.code ?? '';
    return code.startsWith('5') || code.startsWith('PGRST30');
  }

  Future<void> processQueue() async {
    if (_isCurrentlyProcessing || !ref.read(isOnlineProvider)) return;
    final queue = await _ensureQueueBox();
    if (queue == null) return;
    if (queue.isEmpty) {
      if (_metaDirty) await _signalOthers();
      return;
    }

    _isCurrentlyProcessing = true;
    state = state.copyWith(isSyncing: true, clearLastError: true);

    final client = ref.read(supabaseClientProvider);
    final failedThisRun = <dynamic>{};
    final blockedDocs = <String>{}; // jaga urutan per-dokumen
    var hasChanges = false;

    try {
      var progress = true;
      while (progress && ref.read(isOnlineProvider)) {
        progress = false;
        final batch = _sortedEntries(queue)
            .where((e) =>
                !failedThisRun.contains(e.key) &&
                !blockedDocs.contains(
                    '${e.value.collection}:${e.value.documentId}'))
            .take(50)
            .toList();
        if (batch.isEmpty) break;

        final done = <dynamic>[];
        var stop = false;

        for (final entry in batch) {
          final task = entry.value;
          final docKey = '${task.collection}:${task.documentId}';
          if (blockedDocs.contains(docKey)) continue;

          try {
            await _execute(client, task);
            done.add(entry.key);
          } on PostgrestException catch (e) {
            if (_isTransient(e)) {
              state = state.copyWith(
                  lastError: 'Sync ${task.collection} tertunda: ${e.message}');
              stop = true;
              break;
            }
            // Gagal permanen: lanjutkan dokumen lain, blokir hanya dokumen ini.
            blockedDocs.add(docKey);
            failedThisRun.add(entry.key);
            progress = true;
            await _recordPermanentFailure(queue, entry.key, task, e);
          } catch (e) {
            // Jaringan/timeout: hentikan, coba lagi di siklus berikutnya.
            debugPrint('Sync network error for ${task.collection}: $e');
            state = state.copyWith(lastError: 'Sync ${task.collection} tertunda: $e');
            stop = true;
            break;
          }
        }

        if (done.isNotEmpty) {
          await queue.deleteAll(done);
          hasChanges = true;
          progress = true;
          state = state.copyWith(
              pendingCount: queue.length, lastSyncAt: DateTime.now());
        }
        if (stop) break;
      }

      if (hasChanges || _metaDirty) await _signalOthers();
    } catch (e) {
      debugPrint('Sync Batch FATAL Error: $e');
      state = state.copyWith(lastError: e.toString());
    } finally {
      _isCurrentlyProcessing = false;
      state = state.copyWith(isSyncing: false, pendingCount: queue.length);
    }
  }

  Future<void> _execute(SupabaseClient client, SyncTask task) async {
    final uid = _uid;
    if (uid == null) throw StateError('No session');
    final table = task.collection;

    switch (task.action) {
      case SyncAction.create:
      case SyncAction.update:
        final data = Map<String, dynamic>.from(task.data);
        data.putIfAbsent('id', () => task.documentId);
        _prepareRemotePayload(task, data);
        await client.from(table).upsert({'user_id': uid, ...data});
        break;
      case SyncAction.increment:
        // Delta diterapkan di server (atomik + idempoten per task.id),
        // bukan menimpa nilai absolut.
        await client.rpc('adjust_stock', params: {
          'p_product_id': task.documentId,
          'p_delta': (task.data['delta'] as num).toDouble(),
          'p_op_id': task.id,
        });
        break;
      case SyncAction.delete:
        await client
            .from(table)
            .delete()
            .eq('id', task.documentId)
            .eq('user_id', uid);
        break;
    }
  }

  Future<void> _recordPermanentFailure(
    Box queue,
    dynamic key,
    SyncTask task,
    PostgrestException e,
  ) async {
    final retries = task.retryCount + 1;
    final message = 'Sync ${task.collection} gagal: ${e.message}';
    state = state.copyWith(lastError: message);

    if (retries >= _maxRetries) {
      final uid = _uid;
      if (uid != null) {
        final dead = await LocalDatabase.openBox(uid, 'sync_dead_letter');
        await dead.put(task.id, {
          ...task.copyWith(retryCount: retries, lastError: e.toString()).toMap(),
          'failed_at': DateTime.now().toIso8601String(),
        });
        await queue.delete(key);
        state = state.copyWith(
            pendingCount: queue.length, deadLetterCount: dead.length);
        debugPrint('Sync task ${task.id} -> dead-letter: $e');
      }
      return;
    }

    try {
      await queue.put(
          key, task.copyWith(retryCount: retries, lastError: e.toString()).toMap());
    } catch (queueError) {
      debugPrint('Could not persist sync retry state: $queueError');
    }
  }

  /// Kembalikan task dead-letter ke antrean (mis. setelah skema diperbaiki).
  Future<void> retryDeadLetters() async {
    final uid = _uid;
    final queue = await _ensureQueueBox();
    if (uid == null || queue == null) return;
    final dead = await LocalDatabase.openBox(uid, 'sync_dead_letter');
    for (final key in dead.keys.toList()) {
      final raw = dead.get(key);
      if (raw == null) continue;
      final task = SyncTask.fromMap(Map<String, dynamic>.from(raw as Map))
          .copyWith(retryCount: 0, clearLastError: true);
      await addBatchToQueue([task]);
      await dead.delete(key);
    }
    state = state.copyWith(deadLetterCount: dead.length);
  }

  void _prepareRemotePayload(SyncTask task, Map<String, dynamic> data) {
    // Gambar lokal tidak diunggah (hemat resource cloud).
    final imagePath = data['image_path']?.toString();
    if (imagePath != null && !imagePath.startsWith('http')) {
      data.remove('image_path');
    }
    // Stok bukan nilai yang boleh ditimpa oleh edit biasa: stok hanya berubah
    // lewat `increment` (adjust_stock). `create` membawa stok awal.
    if (task.collection == 'products' && task.action == SyncAction.update) {
      data.remove('stock');
    }
  }
}
