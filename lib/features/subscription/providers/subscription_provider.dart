import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/subscription.dart';
import '../models/subscription_history.dart';
import '../repositories/subscription_repository.dart';
import '../../payment/providers/transaction_provider.dart';

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

  Future<String?> initiateRealPayment(PlanType plan, {String? method}) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return null;

    try {
      final result = await _repository.createPaymentInvoice(
        userId: user.uid,
        plan: plan,
        email: user.email,
        method: method,
      );
      
      // Update local state to pending
      final now = DateTime.now();
      final invoiceUrl = result['invoice_url'] as String?;
      
      final pendingSub = Subscription(
        userId: user.uid,
        planType: plan,
        status: SubscriptionStatus.pending,
        createdAt: state.value?.createdAt ?? now,
        updatedAt: now,
        lastExternalId: invoiceUrl, // Temp store URL here to retrieve in UI
      );
      state = AsyncValue.data(pendingSub);
      
      return invoiceUrl;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> cancelPending() async {
    // In production, we might just refresh to see if it's still pending or paid
    await refresh();
  }
}

final subscriptionHistoryProvider = FutureProvider<List<SubscriptionHistory>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.read(subscriptionRepositoryProvider).getHistory(user.uid);
});

final isPremiumProvider = Provider<bool>((ref) {
  final subAsync = ref.watch(subscriptionStateProvider);
  return subAsync.maybeWhen(
    data: (sub) => sub?.isPremium ?? false,
    orElse: () => false,
  );
});

class GatewayState {
  final String? method;
  final PlanType? plan;
  const GatewayState(this.method, this.plan);
}

class GatewayNotifier extends Notifier<GatewayState> {
  @override
  GatewayState build() => const GatewayState(null, null);
  void set(String? m, PlanType? p) => state = GatewayState(m, p);
  void reset() => state = const GatewayState(null, null);
}

final gatewayStateProvider = NotifierProvider<GatewayNotifier, GatewayState>(GatewayNotifier.new);

final dailyTransactionCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(transactionRepositoryProvider);
  final all = await repo.getAllTransactions();
  final now = DateTime.now();
  return all.where((t) {
    return t.createdAt.year == now.year && 
           t.createdAt.month == now.month && 
           t.createdAt.day == now.day;
  }).length;
});
