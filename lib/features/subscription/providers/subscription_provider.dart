import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/subscription.dart';
import '../models/subscription_history.dart';
import '../repositories/subscription_repository.dart';
import '../services/play_billing_service.dart';
import '../../payment/providers/transaction_provider.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});

final playBillingServiceProvider = Provider<PlayBillingService>((ref) {
  final repository = ref.watch(subscriptionRepositoryProvider);
  final service = PlayBillingService(repository);
  ref.onDispose(() => service.dispose());
  return service;
});

final playBillingProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  final service = ref.watch(playBillingServiceProvider);
  final user = ref.watch(authStateProvider).value;
  if (user != null) {
    await service.initialize(
      userId: user.uid,
      onSubscriptionUpdated: () {
        ref.read(subscriptionStateProvider.notifier).refresh();
      },
      onError: (error) {
        debugPrint('Play Billing error notice: $error');
      },
    );
  }
  return service.products;
});

final subscriptionStateProvider = NotifierProvider<SubscriptionNotifier, AsyncValue<Subscription?>>(SubscriptionNotifier.new);

class SubscriptionNotifier extends Notifier<AsyncValue<Subscription?>> {
  SubscriptionRepository get _repository => ref.read(subscriptionRepositoryProvider);
  RealtimeChannel? _subscriptionChannel;
  String? _listeningUid;

  @override
  AsyncValue<Subscription?> build() {
    ref.onDispose(() => _subscriptionChannel?.unsubscribe());

    // Listen to Auth changes
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        _listenToSubscriptionChanges(user.uid);
        refresh();
      } else {
        _subscriptionChannel?.unsubscribe();
        _subscriptionChannel = null;
        _listeningUid = null;
        state = const AsyncValue.data(null);
      }
    });

    // Initial load
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      // Use Future.microtask to avoid state modification during build
      Future.microtask(() {
        _listenToSubscriptionChanges(user.uid);
        refresh();
      });
    }

    return const AsyncValue.loading();
  }

  void _listenToSubscriptionChanges(String uid) {
    if (_listeningUid == uid) return;
    _subscriptionChannel?.unsubscribe();
    _listeningUid = uid;

    final client = ref.read(supabaseClientProvider);
    _subscriptionChannel = client
        .channel('public:subscriptions:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            refresh();
          },
        )
        .subscribe();
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

  Future<void> buyPlayStoreSubscription(ProductDetails product) async {
    final service = ref.read(playBillingServiceProvider);
    await service.buySubscription(product);
  }

  Future<void> restorePlayStorePurchases() async {
    final service = ref.read(playBillingServiceProvider);
    await service.restorePurchases();
    await refresh();
  }

  Future<void> cancelPending() async {
    await refresh();
  }
}

final subscriptionHistoryProvider = FutureProvider<List<SubscriptionHistory>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.read(subscriptionRepositoryProvider).getHistory(user.uid);
});

final isPremiumProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  // Allow developer / bypass account email check
  if (user?.email != null) {
    final emailLower = user!.email.toLowerCase();
    if (emailLower == 'admin@buildera.com' || emailLower.endsWith('@admin.buildera.com')) {
      return true;
    }
  }

  final subAsync = ref.watch(subscriptionStateProvider);
  return subAsync.maybeWhen(
    data: (sub) => (sub?.isPremium ?? false) || (sub?.isBypassed ?? false),
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
