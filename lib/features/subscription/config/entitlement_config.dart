class EntitlementConfig {
  /// Maximum allowed line items per transaction for the free tier
  static const int freeMaxItemsPerTransaction = 3;

  /// Maximum allowed transactions per day for the free tier
  static const int freeMaxTransactionsPerDay = 10;

  /// Reward bonus transactions granted per ad
  static const int rewardBonusTransactions = 10;

  /// Duration of reward bonus (6 hours)
  static const Duration rewardBonusDuration = Duration(hours: 6);

  /// Maximum reward claims allowed per calendar day
  static const int maxRewardsPerDay = 3;

  /// Offline grace period tolerance for active paid entitlements (72 hours)
  static const int offlineToleranceHours = 72;

  /// Default Asia/Jakarta time zone offset (UTC+7)
  static const Duration asiaJakartaOffset = Duration(hours: 7);

  /// Quota threshold to show remaining quota warning in UI (e.g., <= 3 remaining)
  static const int remainingQuotaWarningThreshold = 3;

  /// Allowed time difference between device clock and stopwatch to detect clock manipulation
  static const Duration maxAllowedClockTamperDrift = Duration(minutes: 2);
}
