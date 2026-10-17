class EntitlementConfig {
  /// Maximum allowed line items per transaction for the free tier
  static const int freeMaxItemsPerTransaction = 3;

  /// Maximum allowed transactions per day for the free tier
  static const int freeMaxTransactionsPerDay = 10;

  /// Default Asia/Jakarta time zone offset (UTC+7)
  static const Duration asiaJakartaOffset = Duration(hours: 7);

  /// Quota threshold to show remaining quota warning in UI (e.g., <= 3 remaining)
  static const int remainingQuotaWarningThreshold = 3;
}
