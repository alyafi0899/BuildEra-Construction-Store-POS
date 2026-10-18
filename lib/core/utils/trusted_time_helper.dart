import 'package:flutter/foundation.dart';
import '../sync/services/local_database.dart';
import '../../features/subscription/config/entitlement_config.dart';

class TrustedTimeHelper {
  static const String _timeMetaKey = 'last_trusted_timestamp';
  static const String _offsetMetaKey = 'server_time_offset_ms';

  static DateTime? _anchorServerUtc;
  static DateTime? _anchorDeviceUtc;
  static Stopwatch? _stopwatch;

  /// Returns trusted UTC DateTime
  static DateTime nowUtc({int? offsetMs, DateTime? lastTrusted}) {
    final deviceNowUtc = DateTime.now().toUtc();
    final effectiveOffset = offsetMs ?? 0;

    // 1. Check for forward clock jump via Stopwatch
    if (_anchorServerUtc != null && _anchorDeviceUtc != null && _stopwatch != null) {
      final deviceDiff = deviceNowUtc.difference(_anchorDeviceUtc!);
      final stopwatchDiff = _stopwatch!.elapsed;

      if ((deviceDiff - stopwatchDiff).abs() > EntitlementConfig.maxAllowedClockTamperDrift) {
        debugPrint('TrustedTimeHelper: Clock manipulation detected via Stopwatch! Using anchor + stopwatch.');
        return _anchorServerUtc!.add(_stopwatch!.elapsed);
      }
    }

    var trustedUtc = deviceNowUtc.add(Duration(milliseconds: effectiveOffset));

    // 2. Check for backward clock rollback
    if (lastTrusted != null && trustedUtc.isBefore(lastTrusted)) {
      debugPrint('TrustedTimeHelper: Backward clock rollback detected! Using last trusted time.');
      trustedUtc = lastTrusted;
    }

    return trustedUtc;
  }

  /// Returns trusted Asia/Jakarta DateTime (UTC + 7) ONLY for daily transaction quota day rollover
  static DateTime nowJakarta({int? offsetMs, DateTime? lastTrusted}) {
    return nowUtc(offsetMs: offsetMs, lastTrusted: lastTrusted).add(EntitlementConfig.asiaJakartaOffset);
  }

  /// Deprecated alias for nowJakarta
  static DateTime getTrustedJakartaTime({int? offsetMs, DateTime? lastTrusted}) {
    return nowJakarta(offsetMs: offsetMs, lastTrusted: lastTrusted);
  }

  /// Persists current trusted server time and offset to Hive metadata box
  static Future<void> saveTrustedTime(String uid, DateTime serverTime) async {
    final localNowUtc = DateTime.now().toUtc();
    final offsetMs = serverTime.toUtc().difference(localNowUtc).inMilliseconds;

    _anchorServerUtc = serverTime.toUtc();
    _anchorDeviceUtc = localNowUtc;
    _stopwatch = Stopwatch()..start();

    await LocalDatabase.setMetadata(uid, _offsetMetaKey, offsetMs);
    await LocalDatabase.setMetadata(uid, _timeMetaKey, serverTime.toUtc().toIso8601String());
  }

  /// Fetches get_server_time RPC from Supabase and saves trusted time anchor
  static Future<void> syncFromServer(SupabaseClient client, String uid) async {
    try {
      final res = await client.rpc('get_server_time');
      if (res != null) {
        final serverTime = DateTime.tryParse(res.toString());
        if (serverTime != null) {
          await saveTrustedTime(uid, serverTime);
        }
      }
    } catch (e) {
      debugPrint('TrustedTimeHelper syncFromServer notice (offline/failed): $e');
    }
  }

  /// Retrieves saved offset and last trusted timestamp from Hive metadata
  static Future<({int offsetMs, DateTime? lastTrusted})> getSavedTimeInfo(String uid) async {
    try {
      final offsetRaw = await LocalDatabase.getMetadata(uid, _offsetMetaKey);
      final offsetMs = offsetRaw is int ? offsetRaw : 0;

      final lastTrustedRaw = await LocalDatabase.getMetadata(uid, _timeMetaKey);
      final lastTrusted = lastTrustedRaw is String ? DateTime.tryParse(lastTrustedRaw) : null;

      return (offsetMs: offsetMs, lastTrusted: lastTrusted);
    } catch (_) {
      return (offsetMs: 0, lastTrusted: null);
    }
  }

  /// Checks if two Jakarta DateTime objects fall on the same day in Asia/Jakarta
  static bool isSameJakartaDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
