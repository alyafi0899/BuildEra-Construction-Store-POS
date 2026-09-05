import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';

class SubscriptionRepository {
  final SupabaseClient _client;

  SubscriptionRepository(this._client);

  Future<Subscription?> getSubscription(String userId) async {
    final response = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Subscription.fromMap(response);
  }

  Future<void> upsertSubscription(Subscription subscription) async {
    await _client.from('subscriptions').upsert(subscription.toMap());
  }

  /// Dummy method to simulate payment success
  Future<void> simulatePaymentSuccess(String userId, PlanType plan) async {
    final now = DateTime.now();
    final duration = plan == PlanType.yearly ? const Duration(days: 365) : const Duration(days: 30);
    final expiry = now.add(duration);
    
    final subscription = Subscription(
      userId: userId,
      planType: plan,
      status: SubscriptionStatus.active,
      expiresAt: expiry,
      createdAt: now,
      updatedAt: now,
    );

    await upsertSubscription(subscription);
  }
}
