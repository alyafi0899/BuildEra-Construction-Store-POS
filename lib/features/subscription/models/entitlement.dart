import '../config/entitlement_config.dart';

enum EntitlementTier { free, premium }
enum EntitlementSource { play, bypass, offlineCache }

enum PremiumFeature { analytics, excelImport, restock }

class Entitlement {
  final EntitlementTier tier;
  final EntitlementSource source;
  final DateTime? validUntil;
  final int maxItemsPerTransaction;
  final int? maxTransactionsPerDay; // null = unlimited
  final Set<PremiumFeature> unlockedFeatures;
  final bool isTrial;
  final bool isResolved;

  const Entitlement({
    required this.tier,
    required this.source,
    this.validUntil,
    required this.maxItemsPerTransaction,
    this.maxTransactionsPerDay,
    required this.unlockedFeatures,
    this.isTrial = false,
    this.isResolved = true,
  });

  bool get isPremium => tier == EntitlementTier.premium;
  bool get isFree => tier == EntitlementTier.free;

  bool isFeatureUnlocked(PremiumFeature feature) {
    if (isPremium) return true;
    return unlockedFeatures.contains(feature);
  }

  factory Entitlement.unresolved() {
    return Entitlement(
      tier: EntitlementTier.free,
      source: EntitlementSource.offlineCache,
      maxItemsPerTransaction: EntitlementConfig.freeMaxItemsPerTransaction,
      maxTransactionsPerDay: EntitlementConfig.freeMaxTransactionsPerDay,
      unlockedFeatures: const {},
      isTrial: false,
      isResolved: false,
    );
  }

  factory Entitlement.free({
    EntitlementSource source = EntitlementSource.offlineCache,
    bool isResolved = true,
  }) {
    return Entitlement(
      tier: EntitlementTier.free,
      source: source,
      maxItemsPerTransaction: EntitlementConfig.freeMaxItemsPerTransaction,
      maxTransactionsPerDay: EntitlementConfig.freeMaxTransactionsPerDay,
      unlockedFeatures: const {},
      isTrial: false,
      isResolved: isResolved,
    );
  }

  factory Entitlement.premium({
    EntitlementSource source = EntitlementSource.play,
    DateTime? validUntil,
    bool isTrial = false,
    bool isResolved = true,
  }) {
    return Entitlement(
      tier: EntitlementTier.premium,
      source: source,
      validUntil: validUntil,
      maxItemsPerTransaction: 999999,
      maxTransactionsPerDay: null,
      unlockedFeatures: PremiumFeature.values.toSet(),
      isTrial: isTrial,
      isResolved: isResolved,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tier': tier.name,
      'source': source.name,
      'valid_until': validUntil?.toIso8601String(),
      'max_items_per_transaction': maxItemsPerTransaction,
      'max_transactions_per_day': maxTransactionsPerDay,
      'unlocked_features': unlockedFeatures.map((f) => f.name).toList(),
      'is_trial': isTrial,
    };
  }

  factory Entitlement.fromMap(Map<String, dynamic> map, {bool isResolved = true}) {
    final tier = EntitlementTier.values.byName(map['tier'] as String? ?? 'free');
    final source = EntitlementSource.values.byName(map['source'] as String? ?? 'offlineCache');
    final validUntilStr = map['valid_until'] as String?;
    final validUntil = validUntilStr != null ? DateTime.tryParse(validUntilStr) : null;
    final maxItems = map['max_items_per_transaction'] as int? ?? EntitlementConfig.freeMaxItemsPerTransaction;
    final maxTrans = map['max_transactions_per_day'] as int?;
    final isTrial = map['is_trial'] as bool? ?? false;

    if (tier == EntitlementTier.premium) {
      return Entitlement.premium(
        source: source,
        validUntil: validUntil,
        isTrial: isTrial,
        isResolved: isResolved,
      );
    }

    return Entitlement(
      tier: EntitlementTier.free,
      source: source,
      validUntil: validUntil,
      maxItemsPerTransaction: maxItems,
      maxTransactionsPerDay: maxTrans ?? EntitlementConfig.freeMaxTransactionsPerDay,
      unlockedFeatures: {},
      isTrial: false,
      isResolved: isResolved,
    );
  }
}
