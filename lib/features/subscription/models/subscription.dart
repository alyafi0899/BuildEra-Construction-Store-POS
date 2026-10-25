enum PlanType {
  free,
  monthly,
  yearly;

  static PlanType fromString(String? value) {
    return PlanType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PlanType.free,
    );
  }

  String get displayName {
    switch (this) {
      case PlanType.monthly:
        return 'Bulanan';
      case PlanType.yearly:
        return 'Tahunan';
      default:
        return 'Gratis';
    }
  }
}

enum SubscriptionStatus {
  active,
  canceled,
  grace,
  onHold,
  paused,
  expired,
  none;

  static SubscriptionStatus fromString(String? value) {
    if (value == null || value.isEmpty) return SubscriptionStatus.none;
    final val = value.toLowerCase().trim();
    if (val == 'trial') return SubscriptionStatus.active;
    if (val == 'pending') return SubscriptionStatus.none;
    if (val == 'on_hold' || val == 'onhold') return SubscriptionStatus.onHold;
    return SubscriptionStatus.values.firstWhere(
      (e) => e.name == val,
      orElse: () => SubscriptionStatus.none,
    );
  }
}

class Subscription {
  final String userId;
  final PlanType planType;
  final SubscriptionStatus status;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? lastExternalId;
  final DateTime? gracePeriodEndsAt;
  final bool isBypassed;
  final bool isTrial;
  final String? source;
  final String? playPurchaseToken;

  const Subscription({
    required this.userId,
    required this.planType,
    required this.status,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.lastExternalId,
    this.gracePeriodEndsAt,
    this.isBypassed = false,
    this.isTrial = false,
    this.source,
    this.playPurchaseToken,
  });

  bool get isPremium => isPremiumAt(DateTime.now().toUtc());

  bool isPremiumAt(DateTime nowUtc) {
    if (isBypassed) {
      return true;
    }
    if (planType == PlanType.free) {
      return false;
    }
    if (status != SubscriptionStatus.active &&
        status != SubscriptionStatus.grace &&
        status != SubscriptionStatus.canceled) {
      return false;
    }

    final now = nowUtc.toUtc();
    if (gracePeriodEndsAt != null && gracePeriodEndsAt!.toUtc().isBefore(now)) {
      return false;
    }
    if (gracePeriodEndsAt == null &&
        expiresAt != null &&
        expiresAt!.toUtc().isBefore(now)) {
      return false;
    }

    return true;
  }

  bool isGracePeriodAt(DateTime nowUtc) {
    if (planType == PlanType.free || expiresAt == null) return false;
    final now = nowUtc.toUtc();
    return now.isAfter(expiresAt!.toUtc()) &&
        (gracePeriodEndsAt == null || now.isBefore(gracePeriodEndsAt!.toUtc()));
  }

  bool get isGracePeriod => isGracePeriodAt(DateTime.now().toUtc());

  int daysRemainingAt(DateTime nowUtc) {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.toUtc().difference(nowUtc.toUtc()).inDays;
    return diff < 0 ? 0 : diff;
  }

  int get daysRemaining => daysRemainingAt(DateTime.now().toUtc());

  int get daysActive {
    return DateTime.now().difference(createdAt).inDays;
  }

  bool isNearExpiryAt(DateTime nowUtc) {
    if (isBypassed) return false;
    final remaining = daysRemainingAt(nowUtc);
    return isPremiumAt(nowUtc) && remaining <= 5;
  }

  bool get isNearExpiry => isNearExpiryAt(DateTime.now().toUtc());

  factory Subscription.free(String userId) {
    return Subscription(
      userId: userId,
      planType: PlanType.free,
      status: SubscriptionStatus.none,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      userId: (map['user_id'] ?? '').toString(),
      planType: PlanType.fromString(map['plan_type'] as String?),
      status: SubscriptionStatus.fromString(map['status'] as String?),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'].toString())
          : null,
      createdAt: map['created_at'] != null
          ? (DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? (DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      lastExternalId: map['last_external_id'] as String?,
      gracePeriodEndsAt: map['grace_period_ends_at'] != null
          ? DateTime.tryParse(map['grace_period_ends_at'].toString())
          : null,
      isBypassed: map['is_bypassed'] == true ||
          map['is_bypassed']?.toString().toLowerCase() == 'true',
      isTrial: map['is_trial'] == true ||
          map['is_trial']?.toString().toLowerCase() == 'true',
      source: map['source'] as String?,
      playPurchaseToken: map['play_purchase_token'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'plan_type': planType.name,
      'status': status == SubscriptionStatus.onHold ? 'on_hold' : status.name,
      'expires_at': expiresAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'last_external_id': lastExternalId,
      'grace_period_ends_at': gracePeriodEndsAt?.toIso8601String(),
      'is_bypassed': isBypassed,
      'is_trial': isTrial,
    };
  }

  Subscription copyWith({
    String? userId,
    PlanType? planType,
    SubscriptionStatus? status,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastExternalId,
    DateTime? gracePeriodEndsAt,
    bool? isBypassed,
    bool? isTrial,
  }) {
    return Subscription(
      userId: userId ?? this.userId,
      planType: planType ?? this.planType,
      status: status ?? this.status,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastExternalId: lastExternalId ?? this.lastExternalId,
      gracePeriodEndsAt: gracePeriodEndsAt ?? this.gracePeriodEndsAt,
      isBypassed: isBypassed ?? this.isBypassed,
      isTrial: isTrial ?? this.isTrial,
    );
  }
}
