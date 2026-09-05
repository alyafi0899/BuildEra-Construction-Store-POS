import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});

final subscriptionStateProvider = NotifierProvider<SubscriptionNotifier, AsyncValue<Subscription?>>(SubscriptionNotifier.new);

class SubscriptionNotifier extends Notifier<AsyncValue<Subscription?>> {
  SubscriptionRepository get _repository => ref.read(subscriptionRepositoryProvider);

  @override
  AsyncValue<Subscription?> build() {
    // Listen to Auth changes
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        refresh();
      } else {
        state = const AsyncValue.data(null);
      }
    });

    // Initial load
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      // Use Future.microtask to avoid state modification during build
      Future.microtask(() => refresh());
    }

    return const AsyncValue.loading();
  }

  Future<void> refresh() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final subscription = await _repository.getSubscription(user.uid);
      state = AsyncValue.data(subscription ?? Subscription.free(user.uid));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> upgradeDummy(PlanType plan) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    // Set to pending first
    final now = DateTime.now();
    final pendingSub = Subscription(
      userId: user.uid,
      planType: plan,
      status: SubscriptionStatus.pending,
      createdAt: state.value?.createdAt ?? now,
      updatedAt: now,
    );
    state = AsyncValue.data(pendingSub);
    await _repository.upsertSubscription(pendingSub);
  }

  Future<void> confirmDummyPayment(PlanType plan) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      state = const AsyncValue.loading();
      await _repository.simulatePaymentSuccess(user.uid, plan);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> cancelPending() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    
    // Revert to free/none in dummy mode
    final sub = Subscription.free(user.uid);
    state = AsyncValue.data(sub);
    await _repository.upsertSubscription(sub);
  }
}

final isPremiumProvider = Provider<bool>((ref) {
  final subAsync = ref.watch(subscriptionStateProvider);
  return subAsync.maybeWhen(
    data: (sub) => sub?.isPremium ?? false,
    orElse: () => false,
  );
});
