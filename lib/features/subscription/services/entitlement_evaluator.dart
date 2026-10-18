import '../models/entitlement.dart';
import '../config/entitlement_config.dart';

class EntitlementEvaluator {
  /// Evaluates an Entitlement snapshot against current trusted UTC time.
  static Entitlement evaluateSnapshot({
    required Map<String, dynamic>? rawSnapshot,
    required DateTime currentTrustedUtc,
  }) {
    if (rawSnapshot == null || rawSnapshot.isEmpty) {
      return Entitlement.free();
    }

    final entitlement = Entitlement.fromMap(rawSnapshot);
    if (entitlement.isFree) {
      return entitlement;
    }

    // Strict 72-hour offline grace check requires valid server-verified timestamp
    final lastVerifiedStr = rawSnapshot['last_verified_at'] as String?;
    final lastVerified = lastVerifiedStr != null ? DateTime.tryParse(lastVerifiedStr) : null;

    if (lastVerified == null) {
      // Reject legacy snapshots missing server last_verified_at timestamp
      return Entitlement.free();
    }

    final diffHours = currentTrustedUtc.toUtc().difference(lastVerified.toUtc()).inHours;
    if (diffHours > EntitlementConfig.offlineToleranceHours) {
      return Entitlement.free();
    }

    // Expiry check
    if (entitlement.validUntil != null && currentTrustedUtc.isAfter(entitlement.validUntil!)) {
      return Entitlement.free();
    }

    return entitlement;
  }
}
