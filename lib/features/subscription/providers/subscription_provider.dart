import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/subscription.dart';
import '../models/entitlement.dart';
import '../services/entitlement_evaluator.dart';
import '../models/subscription_history.dart';
import '../repositories/subscription_repository.dart';
import '../services/play_billing_service.dart';
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

final playBillingBootstrapProvider = NotifierProvider<PlayBillingBootstrapNotifier, void>(PlayBillingBootstrapNotifier.new);

class PlayBillingBootstrapNotifier extends Notifier<void> {
  String? _bootedUserId;

  PlayBillingService get _service => ref.read(playBillingServiceProvider);

  @override
  void build() {
    ref.keepAlive();

    ref.listen(authStateProvider, (previous, next) async {
      final user = next.value;
      if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || user == null) {
        _service.cancelPendingVerifications();
        _bootedUserId = null;
        return;
      }

      if (_bootedUserId == user.uid) return;
      if (_bootedUserId != null) {
        _service.cancelPendingVerifications();
      }
      _bootedUserId = user.uid;

      try {
        await _service.initialize(
          userId: user.uid,
          onSubscriptionUpdated: () {
            ref.read(subscriptionStateProvider.notifier).refresh();
          },
          onError: (error) {
            final normalized = error.contains('bound to another user')
                ? 'Pembelian ini terikat ke akun toko lain.'
                : 'Pembelian Google Play gagal: $error';
            ref.read(billingUiStateProvider.notifier).setError(normalized);
          },
        );
      } catch (_) {
        // fail silently; initialization should never block POS startup
      }
    }, fireImmediately: true);
  }
}

final playBillingProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  final service = ref.watch(playBillingServiceProvider);
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
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    ref.read(billingUiStateProvider.notifier).setPending('Memproses pembelian Google Play...');
    final service = ref.read(playBillingServiceProvider);
    await service.buySubscription(product, userId: user.uid);
  }

  Future<void> restorePlayStorePurchases() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    ref.read(billingUiStateProvider.notifier).setVerifying('Memeriksa riwayat langganan...');
    final service = ref.read(playBillingServiceProvider);
    await service.restorePurchases();
    await refresh();
    await ref.read(entitlementProvider.notifier).refresh();
    ref.read(billingUiStateProvider.notifier).setSuccess('Proses pemulihan selesai');
  }

  Future<void> cancelPending() async {
    await refresh();
  }
}

// ── Billing UI State Provider ───────────────────────────────────────────────

enum BillingUiStatus { idle, pending, verifying, success, error }

class BillingUiState {
  final BillingUiStatus status;
  final String? message;

  const BillingUiState({this.status = BillingUiStatus.idle, this.message});
}

class BillingUiStateNotifier extends Notifier<BillingUiState> {
  @override
  BillingUiState build() => const BillingUiState();

  void setPending([String? msg]) => state = BillingUiState(status: BillingUiStatus.pending, message: msg);
  void setVerifying([String? msg]) => state = BillingUiState(status: BillingUiStatus.verifying, message: msg);
  void setSuccess([String? msg]) => state = BillingUiState(status: BillingUiStatus.success, message: msg);
  void setError(String msg) => state = BillingUiState(status: BillingUiStatus.error, message: msg);
  void reset() => state = const BillingUiState();
}

final billingUiStateProvider = NotifierProvider<BillingUiStateNotifier, BillingUiState>(BillingUiStateNotifier.new);

// ── Entitlement Provider (Single Source of Truth) ───────────────────────────

final entitlementProvider = NotifierProvider<EntitlementNotifier, Entitlement>(EntitlementNotifier.new);

class EntitlementNotifier extends Notifier<Entitlement> {
  Timer? _expiryTimer;
  Timer? _periodicTimer;

  @override
  Entitlement build() {
    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      if (user != null) {
        refresh();
      } else {
        _cancelTimers();
        state = Entitlement.free(source: EntitlementSource.offlineCache);
      }
    });

    ref.listen(subscriptionStateProvider, (previous, next) {
      next.when(
        data: (sub) {
          _updateFromSubscription(sub, isFromRemote: true);
        },
        error: (err, stack) {
          _loadCachedSnapshotOrKeep();
        },
        loading: () {},
      );
    });

    ref.onDispose(() {
      _cancelTimers();
    });

    final user = ref.read(authStateProvider).value;
    if (user != null) {
      Future.microtask(() => refresh());
    }

    return Entitlement.unresolved();
  }

  void _cancelTimers() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void _scheduleTimers() {
    _cancelTimers();

    final validUntil = state.validUntil;
    if (validUntil != null) {
      final now = TrustedTimeHelper.nowUtc();
      final diff = validUntil.difference(now);
      if (diff.isNegative) {
        Future.microtask(() => refresh());
      } else {
        _expiryTimer = Timer(diff, () => refresh());
      }
    }

    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  Future<Entitlement> ensureResolved({Duration timeout = const Duration(seconds: 3)}) async {
    if (state.isResolved) return state;
    try {
      await refresh().timeout(timeout);
    } catch (_) {}
    return state;
  }

  Future<void> refresh() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      _cancelTimers();
      state = Entitlement.free(source: EntitlementSource.offlineCache);
      return;
    }

    await TrustedTimeHelper.init(user.uid);
    await _loadCachedSnapshotOrKeep();

    try {
      final client = ref.read(supabaseClientProvider);
      await TrustedTimeHelper.syncFromServer(client, user.uid);

      final sub = await ref.read(subscriptionRepositoryProvider).getSubscription(user.uid);
      await _updateFromSubscription(sub ?? Subscription.free(user.uid), isFromRemote: true);
    } catch (_) {
      await _loadCachedSnapshotOrKeep();
    }
  }

  Future<void> _updateFromSubscription(Subscription? sub, {bool isFromRemote = false}) async {
    final user = ref.read(authStateProvider).value;
    final uid = user?.uid;
    final nowServerUtc = TrustedTimeHelper.nowUtc();

    if (sub == null || !sub.isPremiumAt(nowServerUtc)) {
      final freeEntitlement = Entitlement.free(source: EntitlementSource.play);
      state = freeEntitlement;
      if (uid != null && isFromRemote) {
        final map = freeEntitlement.toMap();
        map['last_verified_at'] = nowServerUtc.toIso8601String();
        map['cached_at'] = nowServerUtc.toIso8601String();
        await LocalDatabase.setMetadata(uid, 'cached_entitlement', map);
      }
      _scheduleTimers();
      return;
    }

    final source = sub.isBypassed ? EntitlementSource.bypass : EntitlementSource.play;
    final premiumEntitlement = Entitlement.premium(
      source: source,
      validUntil: sub.expiresAt ?? sub.gracePeriodEndsAt,
      isTrial: sub.isTrial,
    );

    state = premiumEntitlement;
    if (uid != null && isFromRemote) {
      final map = premiumEntitlement.toMap();
      map['last_verified_at'] = nowServerUtc.toIso8601String();
      map['cached_at'] = nowServerUtc.toIso8601String();
      await LocalDatabase.setMetadata(uid, 'cached_entitlement', map);
    }
    _scheduleTimers();
  }

  Future<void> _loadCachedSnapshotOrKeep() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final rawMap = await LocalDatabase.getMetadata(user.uid, 'cached_entitlement');
      if (rawMap != null && rawMap is Map) {
        final currentTrustedUtc = TrustedTimeHelper.nowUtc();

        final evaluated = EntitlementEvaluator.evaluateSnapshot(
          rawSnapshot: Map<String, dynamic>.from(rawMap),
          currentTrustedUtc: currentTrustedUtc,
        );
        state = evaluated;
        _scheduleTimers();
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
