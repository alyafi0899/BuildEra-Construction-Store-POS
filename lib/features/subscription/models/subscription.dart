enum PlanType {
  free,
  monthly,
  yearly;

  static PlanType fromString(String? value) {
    return PlanType.values.firstWhere(
      (e) => e.toString().split('.').last == value,
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
  expired,
  trial,
  pending,
  none;

  static SubscriptionStatus fromString(String? value) {
    return SubscriptionStatus.values.firstWhere(
      (e) => e.toString().split('.').last == value,
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
  });

  bool get isPremium {
    if (isBypassed) return true;
    if (planType == PlanType.free) return false;
    if (status != SubscriptionStatus.active &&
        status != SubscriptionStatus.trial) return false;

    final now = DateTime.now();
    // Use grace period for determining access
    if (gracePeriodEndsAt != null && gracePeriodEndsAt!.isBefore(now))
      return false;
    if (gracePeriodEndsAt == null &&
        expiresAt != null &&
        expiresAt!.isBefore(now)) return false;

    return true;
  }

  bool get isGracePeriod {
    if (planType == PlanType.free || expiresAt == null) return false;
    final now = DateTime.now();
    return now.isAfter(expiresAt!) &&
        (gracePeriodEndsAt == null || now.isBefore(gracePeriodEndsAt!));
  }

  int get daysRemaining {
    if (expiresAt == null) return 0;
    final diff = expiresAt!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  int get daysActive {
    return DateTime.now().difference(createdAt).inDays;
  }

  bool get isNearExpiry {
    final remaining = daysRemaining;
    return isPremium && remaining <= 5;
  }

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
      userId: map['user_id'] as String,
      planType: PlanType.fromString(map['plan_type'] as String?),
      status: SubscriptionStatus.fromString(map['status'] as String?),
      expiresAt: map['expires_at'] != null
          ? DateTime.parse(map['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastExternalId: map['last_external_id'] as String?,
      gracePeriodEndsAt: map['grace_period_ends_at'] != null
          ? DateTime.parse(map['grace_period_ends_at'] as String)
          : null,
      isBypassed: map['is_bypassed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'plan_type': planType.toString().split('.').last,
      'status': status.toString().split('.').last,
      'expires_at': expiresAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
      'last_external_id': lastExternalId,
      'grace_period_ends_at': gracePeriodEndsAt?.toIso8601String(),
      'is_bypassed': isBypassed,
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
    );
  }
}
