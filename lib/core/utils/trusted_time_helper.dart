import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../sync/services/local_database.dart';
import '../../features/subscription/config/entitlement_config.dart';

class TrustedTimeHelper {
  static const String _timeMetaKey = 'last_trusted_timestamp';
  static const String _offsetMetaKey = 'server_time_offset_ms';

  static int _cachedOffsetMs = 0;
  static DateTime? _lastTrustedUtc;
  static DateTime? _maxSeenUtc;
  static bool _isInitialized = false;

  static int get cachedOffsetMs => _cachedOffsetMs;

  /// Loads saved offset and last trusted timestamp from Hive into in-memory state.
  static Future<void> init(String uid) async {
    try {
      final offsetRaw = await LocalDatabase.getMetadata(uid, _offsetMetaKey);
      _cachedOffsetMs = offsetRaw is int ? offsetRaw : 0;

      final lastTrustedRaw = await LocalDatabase.getMetadata(uid, _timeMetaKey);
      _lastTrustedUtc = lastTrustedRaw is String ? DateTime.tryParse(lastTrustedRaw)?.toUtc() : null;
      _maxSeenUtc = _lastTrustedUtc;
      _isInitialized = true;
    } catch (_) {
      _cachedOffsetMs = 0;
      _isInitialized = true;
    }
  }

  /// Returns trusted UTC DateTime based on cached server offset and monotonic clamp.
  ///
  /// Note on Stopwatch and Sleep:
  /// Dart's Stopwatch does NOT advance while the device is sleeping on OS level
  /// (e.g. Android/iOS deep sleep), which causes false positive clock manipulation
  /// triggers if compared against wall time after wake-up.
  /// Therefore, on app resume, a server resync is triggered. When offline or between
  /// syncs, we apply a monotonic maxSeenDeviceUtc clamp guard so the trusted clock
  /// never moves backwards due to user device clock manipulation/rollback.
  static DateTime nowUtc() {
    final rawDeviceUtc = DateTime.now().toUtc();
    var calculated = rawDeviceUtc.add(Duration(milliseconds: _cachedOffsetMs));

    if (_lastTrustedUtc != null && calculated.isBefore(_lastTrustedUtc!)) {
      calculated = _lastTrustedUtc!;
    }

    if (_maxSeenUtc != null) {
      if (calculated.isBefore(_maxSeenUtc!)) {
        calculated = _maxSeenUtc!;
      } else {
        _maxSeenUtc = calculated;
      }
    } else {
      _maxSeenUtc = calculated;
    }

    return calculated;
  }

  /// Returns trusted Asia/Jakarta DateTime (UTC + 7) ONLY for daily transaction quota day rollover.
  static DateTime nowJakarta() {
    return nowUtc().add(EntitlementConfig.asiaJakartaOffset);
  }

  /// Backward-compatible helper used by existing security tests and any older call sites.
  /// This mirrors the trusted-clock logic while returning Jakarta local time.
  static DateTime getTrustedJakartaTime({
    int offsetMs = 0,
    DateTime? lastTrusted,
    DateTime? maxSeenUtc,
  }) {
    final rawDeviceUtc = DateTime.now().toUtc();
    var calculated = rawDeviceUtc.add(Duration(milliseconds: offsetMs));

    if (lastTrusted != null && calculated.isBefore(lastTrusted)) {
      calculated = lastTrusted;
    }

    final observedMax = maxSeenUtc ?? lastTrusted ?? calculated;
    if (calculated.isBefore(observedMax)) {
      calculated = observedMax;
    }

    return calculated.add(EntitlementConfig.asiaJakartaOffset);
  }

  /// Persists current trusted server time and offset to Hive metadata box and in-memory cache
  static Future<void> saveTrustedTime(String uid, DateTime serverTime) async {
    final serverUtc = serverTime.toUtc();
    final localNowUtc = DateTime.now().toUtc();
    final offsetMs = serverUtc.difference(localNowUtc).inMilliseconds;

    _cachedOffsetMs = offsetMs;
    _lastTrustedUtc = serverUtc;
    if (_maxSeenUtc == null || serverUtc.isAfter(_maxSeenUtc!)) {
      _maxSeenUtc = serverUtc;
    }
    _isInitialized = true;

    await LocalDatabase.setMetadata(uid, _offsetMetaKey, offsetMs);
    await LocalDatabase.setMetadata(uid, _timeMetaKey, serverUtc.toIso8601String());
  }

  /// Fetches get_server_time RPC from Supabase and saves trusted time anchor
  static Future<DateTime?> syncFromServer(SupabaseClient client, String uid) async {
    try {
      final res = await client.rpc('get_server_time');
      if (res != null) {
        final serverTime = DateTime.tryParse(res.toString())?.toUtc();
        if (serverTime != null) {
          await saveTrustedTime(uid, serverTime);
          return serverTime;
        }
      }
    } catch (e) {
      debugPrint('TrustedTimeHelper syncFromServer notice (offline/failed): $e');
    }
    return null;
  }

  /// Retrieves saved offset and last trusted timestamp from Hive metadata
  static Future<({int offsetMs, DateTime? lastTrusted})> getSavedTimeInfo(String uid) async {
    if (!_isInitialized) {
      await init(uid);
    }
    return (offsetMs: _cachedOffsetMs, lastTrusted: _lastTrustedUtc);
  }

  /// Checks if two Jakarta DateTime objects fall on the same day in Asia/Jakarta
  static bool isSameJakartaDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
