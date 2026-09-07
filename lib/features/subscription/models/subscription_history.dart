import 'subscription.dart';

class SubscriptionHistory {
  final String id;
  final String userId;
  final PlanType planType;
  final double amount;
  final String status;
  final String? paymentMethod;
  final DateTime? activatedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const SubscriptionHistory({
    required this.id,
    required this.userId,
    required this.planType,
    required this.amount,
    required this.status,
    this.paymentMethod,
    this.activatedAt,
    this.expiresAt,
    required this.createdAt,
  });

  factory SubscriptionHistory.fromMap(Map<String, dynamic> map) {
    return SubscriptionHistory(
      id:            map['id'] as String,
      userId:        map['user_id'] as String,
      planType:      PlanType.fromString(map['plan_type'] as String?),
      amount:        (map['amount'] as num? ?? 0).toDouble(),
      status:        map['status'] as String? ?? 'unknown',
      paymentMethod: map['payment_method'] as String?,
      activatedAt:   map['activated_at'] != null ? DateTime.parse(map['activated_at'] as String) : null,
      expiresAt:     map['expires_at'] != null ? DateTime.parse(map['expires_at'] as String) : null,
      createdAt:     DateTime.parse(map['created_at'] as String),
    );
  }
}
