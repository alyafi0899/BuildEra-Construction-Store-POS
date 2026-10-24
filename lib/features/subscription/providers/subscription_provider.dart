import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
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
          onSubscriptionUpdated: () async {
            await ref.read(subscriptionStateProvider.notifier).refresh();
            await ref.read(entitlementProvider.notifier).refresh();
          },
          onPending: (message) =>
              ref.read(billingUiStateProvider.notifier).setPending(message),
          onVerifying: (message) =>
              ref.read(billingUiStateProvider.notifier).setVerifying(message),
          onSuccess: (message) =>
              ref.read(billingUiStateProvider.notifier).setSuccess(message),
          onCancelled: () =>
              ref.read(billingUiStateProvider.notifier).reset(),
          onError: (error) {
            String normalized = error;
            if (error.contains('bound to another user') || error.contains('terikat ke akun')) {
              normalized = 'Pembelian ini terikat ke akun toko lain. Periksa akun Google Play Anda.';
            } else if (error.contains('tidak ditemukan') || error.contains('token')) {
              normalized = 'Bukti pembelian Google Play tidak dapat ditemukan. Silakan coba lagi.';
            }
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

    try {
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
              ref.read(entitlementProvider.notifier).refresh();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('Realtime channel listen notice: $e');
    }
  }

  Future<Subscription?> refresh({bool rethrowOnError = false}) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      state = const AsyncValue.data(null);
      return null;
    }

    try {
      final subscription = await _repository.getSubscription(user.uid);
      if (ref.mounted) {
        state = AsyncValue.data(subscription ?? Subscription.free(user.uid));
      }
      return subscription;
    } catch (e, st) {
      if (ref.mounted) {
        if (state.value == null) {
          state = AsyncValue.error(e, st);
        }
      }
      if (rethrowOnError) rethrow;
      return null;
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

  Future<bool> buyPlayStoreSubscription(ProductDetails product) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      ref
          .read(billingUiStateProvider.notifier)
          .setError('Silakan masuk untuk membeli langganan.');
      return false;
    }

    final service = ref.read(playBillingServiceProvider);
    final oldPurchaseDetails = service.activePurchaseDetails;
    final currentSubscription = state.value;
    final selectedPlan = product.id == PlayBillingService.yearlyProductId
        ? PlanType.yearly
        : PlanType.monthly;
    final samePlanAlreadyActive = currentSubscription != null &&
        !currentSubscription.isBypassed &&
        currentSubscription.planType == selectedPlan &&
        currentSubscription.isPremiumAt(TrustedTimeHelper.nowUtc());
    if (oldPurchaseDetails?.productID == product.id || samePlanAlreadyActive) {
      ref.read(billingUiStateProvider.notifier).setError(
            'Paket ${selectedPlan == PlanType.yearly ? 'tahunan' : 'bulanan'} sudah aktif. Anda tidak dapat membeli paket yang sama lagi.',
          );
      return false;
    }

    ReplacementMode? replacementMode;
    if (oldPurchaseDetails?.productID == PlayBillingService.monthlyProductId &&
        product.id == PlayBillingService.yearlyProductId) {
      replacementMode = ReplacementMode.withTimeProration;
    } else if (oldPurchaseDetails?.productID ==
            PlayBillingService.yearlyProductId &&
        product.id == PlayBillingService.monthlyProductId) {
      replacementMode = ReplacementMode.deferred;
    }

    final billingState = ref.read(billingUiStateProvider.notifier);
    billingState.setPending('Memproses pembelian Google Play...');
    try {
      final started = await service.buySubscription(
        product,
        userId: user.uid,
        oldPurchaseDetails: oldPurchaseDetails,
        replacementMode: replacementMode,
      );
      if (!started) {
        billingState.setError(
          service.lastError ?? 'Google Play tidak dapat memulai pembelian.',
        );
      }
      return started;
    } catch (error) {
      billingState.setError('Gagal memulai pembelian Google Play: $error');
      return false;
    }
  }

  Future<RestoreSummary> restorePlayStorePurchases() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return const RestoreNothingFound();

    final service = ref.read(playBillingServiceProvider);
    ref.read(billingUiStateProvider.notifier).setVerifying('Memeriksa riwayat langganan...');

    try {
      final restoreFuture = service.waitForRestore(timeout: const Duration(seconds: 90));
      await service.restorePurchases();
      final summary = await restoreFuture;

      if (summary is RestoreSuccess) {
        await refresh(rethrowOnError: true);
        await ref.read(entitlementProvider.notifier).refresh();
        ref.read(billingUiStateProvider.notifier).setSuccess('Langganan dipulihkan');
      } else if (summary is RestoreNothingFound) {
        ref.read(billingUiStateProvider.notifier).reset();
      } else if (summary is RestoreVerifyFailed) {
        ref.read(billingUiStateProvider.notifier).setError(summary.message);
      } else if (summary is RestoreTimedOut) {
        ref.read(billingUiStateProvider.notifier).setVerifying('Verifikasi masih berjalan, coba lagi sebentar lagi');
      }

      return summary;
    } catch (error) {
      final msg = error is PlayVerifyException
          ? error.message
          : 'Gagal memulihkan pembelian: $error';
      ref.read(billingUiStateProvider.notifier).setError(msg);
      return RestoreVerifyFailed(message: msg);
    }
  }

  Future<bool> retryLastFailedVerification() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return false;

    ref.read(billingUiStateProvider.notifier).setVerifying('Memeriksa ulang verifikasi...');
    final service = ref.read(playBillingServiceProvider);
    try {
      final success = await service.retryLastFailedVerification();
      if (success) {
        await refresh(rethrowOnError: true);
        await ref.read(entitlementProvider.notifier).refresh();
      }
      return success;
    } catch (error) {
      final msg = error is PlayVerifyException ? error.message : '$error';
      ref.read(billingUiStateProvider.notifier).setError(msg);
      return false;
    }
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

class EntitlementNotifier extends Notifier<Entitlement> with WidgetsBindingObserver {
  Timer? _expiryTimer;
  Timer? _periodicTimer;
  int _refreshGeneration = 0;
  bool _needReRefresh = false;
  Future<void>? _inFlightRefresh;
  DateTime? _lastResumeRefreshTime;
  static const Duration _minResumeInterval = Duration(seconds: 30);

  @override
  Entitlement build() {
    try {
      WidgetsBinding.instance.addObserver(this);
    } catch (_) {}

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
          _updateFromSubscription(sub, generation: _refreshGeneration, isFromRemote: true);
        },
        error: (err, stack) {
          if (!state.isResolved) {
            _loadCachedSnapshotOrKeep();
          }
        },
        loading: () {},
      );
    });

    ref.onDispose(() {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
      _cancelTimers();
    });

    final user = ref.read(authStateProvider).value;
    if (user != null) {
      Future.microtask(() => refresh());
    }

    return Entitlement.unresolved();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastResumeRefreshTime == null ||
          now.difference(_lastResumeRefreshTime!) >= _minResumeInterval) {
        _lastResumeRefreshTime = now;
        _handleAppResumeRefresh();
      }
    }
  }

  Future<void> _handleAppResumeRefresh() async {
    try {
      await ref.read(subscriptionStateProvider.notifier).refresh();
      await refresh();
    } catch (e) {
      debugPrint('Resume refresh notice: $e');
    }
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
        // Requirement 1.3: Do not schedule immediate repeating microtasks when expired.
        // Schedule a single refresh after 30 seconds minimum.
        _expiryTimer = Timer(const Duration(seconds: 30), () => refresh());
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
    if (_inFlightRefresh != null) {
      _needReRefresh = true;
      return _inFlightRefresh!;
    }

    final currentGen = ++_refreshGeneration;
    final completer = Completer<void>();
    _inFlightRefresh = completer.future;

    try {
      await _performRefresh(currentGen);
    } finally {
      completer.complete();
      _inFlightRefresh = null;
      if (_needReRefresh) {
        _needReRefresh = false;
        Future.microtask(() => refresh());
      }
    }
  }

  Future<void> _performRefresh(int generation) async {
    if (!ref.mounted) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      if (generation >= _refreshGeneration && ref.mounted) {
        _cancelTimers();
        state = Entitlement.free(source: EntitlementSource.offlineCache);
      }
      return;
    }

    await TrustedTimeHelper.init(user.uid);
    if (!ref.mounted) return;

    // Requirement 1.2 [PERUBAHAN A]: Only load cached snapshot on cold start before first fetch completes
    if (!state.isResolved) {
      await _loadCachedSnapshotOrKeep();
      if (!ref.mounted) return;
    }

    try {
      final client = ref.read(supabaseClientProvider);
      await TrustedTimeHelper.syncFromServer(client, user.uid);
      if (!ref.mounted) return;

      final sub = await ref.read(subscriptionRepositoryProvider).getSubscription(user.uid);
      if (!ref.mounted) return;

      await _updateFromSubscription(
        sub ?? Subscription.free(user.uid),
        generation: generation,
        isFromRemote: true,
      );
    } catch (_) {
      if (generation >= _refreshGeneration && ref.mounted) {
        await _loadCachedSnapshotOrKeep();
      }
    }
  }

  Future<void> _updateFromSubscription(
    Subscription? sub, {
    int? generation,
    bool isFromRemote = false,
  }) async {
    if (generation != null && generation < _refreshGeneration) {
      // Skip stale updates from earlier requests
      return;
    }
    if (!ref.mounted) return;

    final user = ref.read(authStateProvider).value;
    final uid = user?.uid;
    final nowServerUtc = TrustedTimeHelper.nowUtc();

    if (sub == null || !sub.isPremiumAt(nowServerUtc)) {
      final freeEntitlement = Entitlement.free(source: EntitlementSource.play);
      if (ref.mounted) {
        state = freeEntitlement;
      }
      if (uid != null && isFromRemote) {
        try {
          final map = freeEntitlement.toMap();
          map['last_verified_at'] = nowServerUtc.toIso8601String();
          map['cached_at'] = nowServerUtc.toIso8601String();
          await LocalDatabase.setMetadata(uid, 'cached_entitlement', map);
        } catch (e) {
          debugPrint('LocalDatabase cache write notice: $e');
        }
      }
      if (ref.mounted) {
        _scheduleTimers();
      }
      return;
    }

    final source = sub.isBypassed ? EntitlementSource.bypass : EntitlementSource.play;

    // Requirement 1.3 [PERUBAHAN C]: Grace period validUntil should use gracePeriodEndsAt
    final isGrace = sub.isGracePeriodAt(nowServerUtc) || sub.status == SubscriptionStatus.grace;
    DateTime? validUntil;
    if (isGrace && sub.gracePeriodEndsAt != null) {
      validUntil = sub.gracePeriodEndsAt;
    } else {
      validUntil = sub.expiresAt ?? sub.gracePeriodEndsAt;
    }

    final premiumEntitlement = Entitlement.premium(
      source: source,
      validUntil: validUntil,
      isTrial: sub.isTrial,
    );

    if (ref.mounted) {
      state = premiumEntitlement;
    }
    if (uid != null && isFromRemote) {
      try {
        final map = premiumEntitlement.toMap();
        map['last_verified_at'] = nowServerUtc.toIso8601String();
        map['cached_at'] = nowServerUtc.toIso8601String();
        await LocalDatabase.setMetadata(uid, 'cached_entitlement', map);
      } catch (e) {
        debugPrint('LocalDatabase cache write notice: $e');
      }
    }
    if (ref.mounted) {
      _scheduleTimers();
    }
  }

  Future<void> _loadCachedSnapshotOrKeep() async {
    if (!ref.mounted) return;
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      final rawMap = await LocalDatabase.getMetadata(user.uid, 'cached_entitlement');
      if (!ref.mounted) return;
      if (rawMap != null && rawMap is Map) {
        final currentTrustedUtc = TrustedTimeHelper.nowUtc();

        final evaluated = EntitlementEvaluator.evaluateSnapshot(
          rawSnapshot: Map<String, dynamic>.from(rawMap),
          currentTrustedUtc: currentTrustedUtc,
        );
        if (ref.mounted) {
          state = evaluated;
          _scheduleTimers();
        }
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
