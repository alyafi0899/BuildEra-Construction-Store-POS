import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/store_settings.dart';
import '../../../core/sync/providers/connectivity_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../core/utils/pin_hasher.dart';

final settingsProvider =
    NotifierProvider<SettingsNotifier, StoreSettings>(SettingsNotifier.new);

/// Sinkronisasi pengaturan toko lewat `public.users`.
///
/// Aturan:
///  * Server (baris `users`) adalah sumber kebenaran; nilai kosong dari server
///    TIDAK diabaikan (user memang bisa mengosongkan alamat, dll).
///  * Hanya field yang berubah yang dikirim (patch), disimpan di Hive sampai
///    sukses terkirim, sehingga edit saat offline tidak hilang.
///  * Field hardware/perangkat (printer, lebar struk, gambar) tetap lokal.
class SettingsNotifier extends Notifier<StoreSettings> {
  static const _patchKey = 'pending_patch';

  String? _uid;
  RealtimeChannel? _channel;
  String? _channelUid;
  DateTime? _lastServerStamp; // updated_at terakhir yang kita tahu (utc)
  bool _flushing = false;
  bool _flushAgain = false;
  Timer? _retryTimer;

  @override
  StoreSettings build() {
    // listen (bukan watch): build() tidak dijalankan ulang tiap token refresh,
    // jadi state tidak ter-reset ke default.
    ref.listen<String?>(
      authStateProvider.select((a) => a.value?.uid),
      (prev, next) => _onUidChanged(next),
      fireImmediately: true,
    );
    ref.listen<bool>(isOnlineProvider, (prev, next) {
      final uid = _uid;
      if (next && uid != null) unawaited(_flushPending(uid));
    });
    ref.onDispose(() {
      _retryTimer?.cancel();
      _teardownChannel();
    });
    return const StoreSettings();
  }

  SupabaseClient get _supabase => ref.read(supabaseClientProvider);
  Future<Box> _getBox(String uid) => LocalDatabase.openBox(uid, 'settings');

  void _onUidChanged(String? uid) {
    if (uid == _uid) return;
    _teardownChannel();
    _retryTimer?.cancel();
    _uid = uid;
    _lastServerStamp = null;

    Future.microtask(() {
      if (_uid != uid) return;
      if (uid == null) {
        state = const StoreSettings();
        return;
      }
      state = const StoreSettings(isLoading: true);
      _listenForRemoteSettings(uid);
      unawaited(_loadSettings(uid));
    });
  }

  void _teardownChannel() {
    _channel?.unsubscribe();
    _channel = null;
    _channelUid = null;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool _same(dynamic a, dynamic b) => jsonEncode(a) == jsonEncode(b);

  Future<Map<String, dynamic>> _readPatch(Box box) async {
    final raw = box.get(_patchKey);
    return raw == null ? <String, dynamic>{} : Map<String, dynamic>.from(raw as Map);
  }

  /// Gabungkan nilai remote ke [local]: field remote menimpa (termasuk string
  /// kosong), KECUALI field yang masih punya perubahan lokal belum terkirim
  /// dan field khusus perangkat.
  Map<String, dynamic> _mergeRemote(
    Map<String, dynamic> local,
    Map<String, dynamic> remote,
    Map<String, dynamic> pendingPatch,
  ) {
    final merged = Map<String, dynamic>.from(local);
    for (final key in const StoreSettings().toRemoteMap().keys) {
      if (!remote.containsKey(key)) continue;
      if (pendingPatch.containsKey(key)) continue;
      merged[key] = remote[key];
    }
    return merged;
  }

  DateTime? _stampOf(Map<String, dynamic> row) =>
      DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toUtc();

  // ── Realtime ─────────────────────────────────────────────────────────────

  void _listenForRemoteSettings(String uid) {
    if (_channelUid == uid) return;
    _teardownChannel();
    _channelUid = uid;
    _channel = _supabase
        .channel('store_settings:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (payload) {
            if (payload.newRecord.isEmpty || _uid != uid) return;
            unawaited(_applyRemoteSettings(uid, payload.newRecord));
          },
        )
        .subscribe();
  }

  Future<void> _applyRemoteSettings(
      String uid, Map<String, dynamic> remoteRow) async {
    // Abaikan echo tulisan kita sendiri dan event usang.
    final stamp = _stampOf(remoteRow);
    final last = _lastServerStamp;
    if (stamp != null && last != null && !stamp.isAfter(last)) return;

    final box = await _getBox(uid);
    if (_uid != uid) return;
    final pending = await _readPatch(box);

    final merged = _mergeRemote(
      state.toMap(),
      LocalDatabase.sanitize(remoteRow),
      pending,
    );
    final settings = StoreSettings.fromMap(merged, isLoading: false);
    state = settings;
    await box.put('store_settings', settings.toMap());
    if (stamp != null) _lastServerStamp = stamp;
  }

  // ── Load ─────────────────────────────────────────────────────────────────

  Future<void> _loadSettings(String uid) async {
    StoreSettings? cached;

    // 1. Tampilkan cache lokal secepatnya.
    try {
      final box = await _getBox(uid);
      final raw = box.get('store_settings');
      if (raw != null) {
        cached = StoreSettings.fromMap(Map<String, dynamic>.from(raw as Map));
        state = cached.copyWith(isLoading: true);
      }
    } catch (e) {
      debugPrint('Hive Load Error: $e');
    }

    // 2. Metadata auth: hanya fallback kalau baris `users` BELUM ada.
    Map<String, dynamic> metadata = {};
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser?.id == uid) {
        metadata = Map<String, dynamic>.from(authUser!.userMetadata ?? {});
        metadata['login_email'] ??= authUser.email;
      }
    } catch (e) {
      debugPrint('Auth metadata load error: $e');
    }

    // 3. Kirim dulu perubahan lokal yang tertunda (jangan ditimpa data remote).
    await _flushPending(uid);
    if (_uid != uid) return;

    // 4. Tarik dari Supabase (dengan retry).
    var retries = 3;
    while (retries > 0) {
      try {
        final response = await _supabase
            .from('users')
            .select()
            .eq('id', uid)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
        if (_uid != uid) return;

        final box = await _getBox(uid);
        final pending = await _readPatch(box);
        final base = cached?.toMap() ?? const StoreSettings().toMap();

        if (response != null) {
          final remote = LocalDatabase.sanitize(response);
          final merged = _mergeRemote(base, remote, pending);
          final settings = StoreSettings.fromMap(merged, isLoading: false);
          state = settings;
          await box.put('store_settings', settings.toMap());
          final stamp = _stampOf(remote);
          if (stamp != null) _lastServerStamp = stamp;
        } else {
          // Baris belum ada: seed dari metadata registrasi.
          final seeded = StoreSettings.fromMap(
              {...base, ...metadata}, isLoading: false);
          state = seeded;
          await box.put('store_settings', seeded.toMap());
          if (metadata.isNotEmpty) {
            try {
              await _supabase.from('users').upsert({
                'id': uid,
                ...seeded.toRemoteMap(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              }).timeout(const Duration(seconds: 10));
            } catch (e) {
              debugPrint('Could not seed public.users from auth metadata: $e');
            }
          }
        }

        await _upgradeLegacyPin();
        return;
      } catch (e) {
        retries--;
        if (retries == 0) {
          debugPrint('Supabase Settings Fatal Error: $e');
          final fallback = StoreSettings.fromMap(
              {...(cached?.toMap() ?? const StoreSettings().toMap()), ...metadata},
              isLoading: false);
          state = fallback;
          try {
            final box = await _getBox(uid);
            await box.put('store_settings', fallback.toMap());
          } catch (cacheError) {
            debugPrint('Settings fallback cache error: $cacheError');
          }
        } else {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
  }

  Future<void> refreshFromRemote() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    _uid = uid;
    await _loadSettings(uid);
  }

  /// PIN lama (plaintext) di-hash sekali; hasilnya ikut tersinkron.
  Future<void> _upgradeLegacyPin() async {
    final pin = state.securityPin;
    if (pin == null || pin.isEmpty || PinHasher.isHashed(pin)) return;
    await updateSettings(state.copyWith(securityPin: PinHasher.hash(pin)));
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Future<void> updateSettings(StoreSettings settings, {String? uid}) async {
    final targetUid = uid ?? ref.read(authStateProvider).value?.uid;
    if (targetUid == null) throw 'User session not found';

    final previous = state;

    // 1. State + cache lokal LANGSUNG.
    state = settings.copyWith(isLoading: false);
    final box = await _getBox(targetUid);
    try {
      await box.put('store_settings', settings.toMap());
    } catch (e) {
      debugPrint('Hive Settings Cache Error: $e');
    }

    // 2. Hitung diff field yang dibagi antar device.
    final oldMap = previous.toRemoteMap();
    final newMap = settings.toRemoteMap();
    final changed = <String, dynamic>{
      for (final e in newMap.entries)
        if (!_same(oldMap[e.key], e.value)) e.key: e.value,
    };
    if (changed.isEmpty) return; // mis. hanya field printer/gambar (lokal)

    // 3. Simpan sebagai patch tertunda, lalu coba kirim.
    final patch = await _readPatch(box)
      ..addAll(changed);
    await box.put(_patchKey, patch);
    await _flushPending(targetUid);
  }

  Future<void> _flushPending(String uid) async {
    if (_flushing) {
      _flushAgain = true;
      return;
    }
    _flushing = true;
    try {
      do {
        _flushAgain = false;
        final box = await _getBox(uid);
        final patch = await _readPatch(box);
        if (patch.isEmpty) return;
        if (!ref.read(isOnlineProvider)) return;

        try {
          final res = await _supabase
              .from('users')
              .upsert({
                'id': uid,
                ...patch,
                // Server (trigger) menimpa ini; fallback bila trigger belum ada.
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .select('updated_at')
              .single()
              .timeout(const Duration(seconds: 10));

          final stamp = _stampOf(Map<String, dynamic>.from(res));
          if (stamp != null) _lastServerStamp = stamp;

          // Hapus hanya field yang nilainya persis yang barusan terkirim
          // (edit baru selama request berjalan tetap tertunda).
          final current = await _readPatch(box);
          for (final e in patch.entries) {
            if (current.containsKey(e.key) && _same(current[e.key], e.value)) {
              current.remove(e.key);
            }
          }
          if (current.isEmpty) {
            await box.delete(_patchKey);
          } else {
            await box.put(_patchKey, current);
            _flushAgain = true;
          }
        } catch (e) {
          debugPrint('Settings flush failed, will retry: $e');
          _retryTimer?.cancel();
          _retryTimer =
              Timer(const Duration(seconds: 30), () => _flushPending(uid));
          return;
        }
      } while (_flushAgain);
    } finally {
      _flushing = false;
    }
  }
}
