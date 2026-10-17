import 'package:flutter/foundation.dart';
import '../sync/services/local_database.dart';

class TrustedTimeHelper {
  static const String _timeMetaKey = 'last_trusted_timestamp';
  static const String _offsetMetaKey = 'server_time_offset_ms';

  /// Returns trusted Asia/Jakarta time (UTC + 7) taking into account server time offset and rollback checks
  static DateTime getTrustedJakartaTime({int? offsetMs, DateTime? lastTrusted}) {
    final nowUtc = DateTime.now().toUtc();
    final effectiveOffset = offsetMs ?? 0;
    final adjustedUtc = nowUtc.add(Duration(milliseconds: effectiveOffset));

    var trustedUtc = adjustedUtc;
    if (lastTrusted != null && trustedUtc.isBefore(lastTrusted)) {
      debugPrint('TrustedTimeHelper: Device clock rollback detected! Falling back to last trusted time.');
      trustedUtc = lastTrusted;
    }

    // Asia/Jakarta is UTC+7
    return trustedUtc.add(const Duration(hours: 7));
  }

  /// Persists current trusted server time and offset to Hive metadata box
  static Future<void> saveTrustedTime(String uid, DateTime serverTime) async {
    final localNowUtc = DateTime.now().toUtc();
    final offsetMs = serverTime.toUtc().difference(localNowUtc).inMilliseconds;

    await LocalDatabase.setMetadata(uid, _offsetMetaKey, offsetMs);
    await LocalDatabase.setMetadata(uid, _timeMetaKey, serverTime.toUtc().toIso8601String());
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
