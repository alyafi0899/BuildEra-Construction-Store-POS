import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/subscription.dart';
import '../models/entitlement.dart';
import '../config/entitlement_config.dart';
import '../models/subscription_history.dart';
import '../repositories/subscription_repository.dart';
import '../services/play_billing_service.dart';
import '../../payment/providers/transaction_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../../core/utils/trusted_time_helper.dart';

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
    try {
      await service.initialize(
        userId: user.uid,
        onSubscriptionUpdated: () {
          ref.read(subscriptionStateProvider.notifier).refresh();
        },
        onError: (error) {
          debugPrint('Play Billing error notice: $error');
        },
      );
    } catch (e) {
      debugPrint('Play Billing background init notice (failing silently): $e');
    }
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

    // Keep previous state while revalidating in background
    try {
      final subscription = await _repository.getSubscription(user.uid);
      state = AsyncValue.data(subscription ?? Subscription.free(user.uid));
    } catch (e, st) {
      // Do not overwrite previous valid data with error
      if (state.value == null) {
        state = AsyncValue.error(e, st);
      }
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
      
      final now = DateTime.now();
      final invoiceUrl = result['invoice_url'] as String?;
      
      final pendingSub = Subscription(
        userId: user.uid,
        planType: plan,
        status: SubscriptionStatus.none,
        createdAt: state.value?.createdAt ?? now,
        updatedAt: now,
        lastExternalId: invoiceUrl,
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

// ── Entitlement Provider (Single Source of Truth) ───────────────────────────

final entitlementProvider = NotifierProvider<EntitlementNotifier, Entitlement>(EntitlementNotifier.new);

class EntitlementNotifier extends Notifier<Entitlement> {
  @override
  Entitlement build() {
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        refresh();
      } else {
        state = Entitlement.free(source: EntitlementSource.offlineCache);
      }
    });

    ref.listen(subscriptionStateProvider, (previous, next) {
      next.when(
        data: (sub) {
          _updateFromSubscription(sub);
        },
        error: (err, stack) {
          _loadCachedSnapshotOrKeep();
        },
        loading: () {
          // Stale-while-revalidate: keep current entitlement during background updates
        },
      );
    });

    final user = ref.read(authStateProvider).value;
    if (user != null) {
      Future.microtask(() => refresh());
    }

    return Entitlement.free(source: EntitlementSource.offlineCache);
  }

  Future<void> refresh() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      state = Entitlement.free(source: EntitlementSource.offlineCache);
      return;
    }

    await _loadCachedSnapshotOrKeep();

    try {
      final sub = await ref.read(subscriptionRepositoryProvider).getSubscription(user.uid);
      await _updateFromSubscription(sub ?? Subscription.free(user.uid));
    } catch (_) {
      await _loadCachedSnapshotOrKeep();
    }
  }

  Future<void> _updateFromSubscription(Subscription? sub) async {
    final user = ref.read(authStateProvider).value;
    final uid = user?.uid;

    if (sub == null || !sub.isPremium) {
      final freeEntitlement = Entitlement.free(source: EntitlementSource.play);
      state = freeEntitlement;
      if (uid != null) {
        final map = freeEntitlement.toMap();
        map['last_verified_at'] = DateTime.now().toIso8601String();
        await LocalDatabase.setMetadata(uid, 'cached_entitlement', map);
      }
      return;
    }

    final source = sub.isBypassed ? EntitlementSource.bypass : EntitlementSource.play;
    final premiumEntitlement = Entitlement.premium(
      source: source,
      validUntil: sub.expiresAt ?? sub.gracePeriodEndsAt,
      isTrial: sub.isTrial,
    );

    state = premiumEntitlement;
    if (uid != null) {
      final map = premiumEntitlement.toMap();
      map['last_verified_at'] = DateTime.now().toIso8601String();
      await LocalDatabase.setMetadata(uid, 'cached_entitlement', map);
    }
  }

  Future<void> _loadCachedSnapshotOrKeep() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final rawMap = await LocalDatabase.getMetadata(user.uid, 'cached_entitlement');
      if (rawMap != null && rawMap is Map) {
        final map = Map<String, dynamic>.from(rawMap);
        final cached = Entitlement.fromMap(map);
        
        final lastVerifiedStr = map['last_verified_at'] as String?;
        final lastVerified = lastVerifiedStr != null ? DateTime.tryParse(lastVerifiedStr) : null;

        if (cached.isPremium && lastVerified != null) {
          final timeInfo = await TrustedTimeHelper.getSavedTimeInfo(user.uid);
          final nowJakarta = TrustedTimeHelper.getTrustedJakartaTime(
            offsetMs: timeInfo.offsetMs,
            lastTrusted: timeInfo.lastTrusted,
          );

          final diffHours = nowJakarta.toUtc().difference(lastVerified.toUtc()).inHours;
          if (diffHours <= EntitlementConfig.offlineToleranceHours) {
            state = cached;
            return;
          } else {
            debugPrint('Entitlement offline snapshot expired (> 72h). Downgrading to free.');
            state = Entitlement.free(source: EntitlementSource.offlineCache);
            return;
          }
        }
        state = cached;
      }
    } catch (e) {
      debugPrint('Entitlement snapshot read error: $e');
    }
  }
}

final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(entitlementProvider).isPremium;
});

final subscriptionHistoryProvider = FutureProvider<List<SubscriptionHistory>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return [];
  return ref.read(subscriptionRepositoryProvider).getHistory(user.uid);
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
    return TrustedTimeHelper.isSameJakartaDay(t.createdAt, now);
  }).length;
});
