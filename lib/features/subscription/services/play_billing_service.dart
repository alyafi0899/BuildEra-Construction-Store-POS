import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:url_launcher/url_launcher.dart';
import '../repositories/subscription_repository.dart';
import '../../../core/utils/trusted_time_helper.dart';

typedef PlayPurchaseVerifier = Future<Map<String, dynamic>> Function({
  required String purchaseToken,
  required String productId,
});

sealed class RestoreSummary {
  const RestoreSummary();
}

class RestoreSuccess extends RestoreSummary {
  const RestoreSuccess();
}

class RestoreNothingFound extends RestoreSummary {
  const RestoreNothingFound();
}

class RestoreVerifyFailed extends RestoreSummary {
  final String? code;
  final String message;

  const RestoreVerifyFailed({this.code, required this.message});
}

class RestoreTimedOut extends RestoreSummary {
  const RestoreTimedOut();
}

class PlayBillingService {
  static const String monthlyProductId = 'buildera_monthly';
  static const String yearlyProductId = 'buildera_yearly';
  static const Set<String> productIds = {monthlyProductId, yearlyProductId};

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Set<String> _verifyingTokens = {};
  final Set<String> _activeVerificationTokens = {};
  final Map<String, Timer> _verificationTimers = {};
  final Map<String, int> _verificationAttempts = {};
  final Map<String, _PendingVerification> _pendingVerifications = {};
  _RestoreWaiter? _restoreWaiter;
  PurchaseDetails? _activePurchaseDetails;
  String? _userId;

  String? _lastFailedToken;
  String? _lastFailedProductId;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  String? _lastError;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => List.unmodifiable(_products);
  String? get lastError => _lastError;
  bool get isVerifying => _activeVerificationTokens.isNotEmpty;
  PurchaseDetails? get activePurchaseDetails => _activePurchaseDetails;
  bool get hasLastFailedToken => _lastFailedToken != null && _lastFailedProductId != null;

  static const String androidApplicationId = 'com.solutivostudio.caltax';

  static Uri manageSubscriptionUri(String productId) => Uri.https(
        'play.google.com',
        '/store/account/subscriptions',
        {'sku': productId, 'package': androidApplicationId},
      );

  static Future<bool> launchManageSubscription(String productId) =>
      launchUrl(
        manageSubscriptionUri(productId),
        mode: LaunchMode.externalApplication,
      );

  PlayBillingService(SubscriptionRepository repository)
      : _verifyPurchase = repository.verifyPlayPurchase;

  @visibleForTesting
  PlayBillingService.forTesting(this._verifyPurchase);

  final PlayPurchaseVerifier _verifyPurchase;

  /// Initializes Google Play Billing connection and listens to purchase events
  Future<void> initialize({
    required String userId,
    required VoidCallback onSubscriptionUpdated,
    required void Function(String message) onPending,
    required void Function(String message) onVerifying,
    required void Function(String message) onSuccess,
    required VoidCallback onCancelled,
    required void Function(String error) onError,
  }) async {
    if (_userId != null && _userId != userId) {
      cancelPendingVerifications();
      _activePurchaseDetails = null;
    }
    _userId = userId;

    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      _isAvailable = false;
      return;
    }

    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        debugPrint('Google Play Store billing service is unavailable on this device.');
        return;
      }

      // 1. Listen to purchase stream
      _subscription?.cancel();
      _subscription = _iap.purchaseStream.listen(
        (purchaseList) => _onPurchaseListUpdated(
          purchaseList,
          userId,
          onSubscriptionUpdated,
          onPending,
          onVerifying,
          onSuccess,
          onCancelled,
          onError,
        ),
        onError: (error) {
          _lastError = error.toString();
          debugPrint('Play Billing stream notice: $error');
        },
      );

      // 2. Fetch available products from Play Console
      await loadProducts();
    } catch (e) {
      _isAvailable = false;
      _lastError = e.toString();
      debugPrint('PlayBillingService initialize error: $e');
    }
  }

  /// Queries product details from Google Play Console
  Future<List<ProductDetails>> loadProducts() async {
    if (!_isAvailable) return [];

    try {
      final response = await _iap.queryProductDetails(productIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('Play Billing warning: Products not found in Play Console: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      return _products;
    } catch (e) {
      debugPrint('Error loading Play Store products: $e');
      return [];
    }
  }

  /// Triggers purchasing a subscription plan with obfuscatedAccountId and proration mode
  Future<bool> buySubscription(
    ProductDetails productDetails, {
    String? userId,
    PurchaseDetails? oldPurchaseDetails,
    ReplacementMode? replacementMode,
  }) async {
    _lastError = null;
    if (!_isAvailable) return false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final oldGooglePurchase = oldPurchaseDetails is GooglePlayPurchaseDetails
            ? oldPurchaseDetails
            : null;
        if (oldPurchaseDetails != null && oldGooglePurchase == null) {
          throw ArgumentError.value(
            oldPurchaseDetails,
            'oldPurchaseDetails',
            'An Android Google Play purchase is required for a plan change.',
          );
        }
        final googleParam = GooglePlayPurchaseParam(
          productDetails: productDetails,
          applicationUserName: userId,
          changeSubscriptionParam: oldGooglePurchase != null
              ? ChangeSubscriptionParam(
                  oldPurchaseDetails: oldGooglePurchase,
                  replacementMode: replacementMode,
                )
              : null,
        );
        return await _iap.buyNonConsumable(purchaseParam: googleParam);
      } else {
        final purchaseParam = PurchaseParam(
          productDetails: productDetails,
          applicationUserName: userId,
        );
        return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error buying Play Store subscription: $e');
      return false;
    }
  }

  /// Waits for all running/scheduled verifications from restore to settle
  Future<RestoreSummary> waitForRestore({
    Duration timeout = const Duration(seconds: 90),
  }) async {
    final waiter = _RestoreWaiter();
    _restoreWaiter = waiter;
    try {
      final summary = await waiter.completer.future.timeout(
        timeout,
        onTimeout: () => const RestoreTimedOut(),
      );
      return summary;
    } finally {
      if (identical(_restoreWaiter, waiter)) {
        _restoreWaiter = null;
      }
      waiter.dispose();
    }
  }

  /// Restores previous active purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    try {
      await _iap.restorePurchases();
      _restoreWaiter?.checkNoPurchasesAfterDelay();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error restoring Play Store purchases: $e');
      rethrow;
    }
  }

  /// Manually retries verification for the last failed token
  Future<bool> retryLastFailedVerification() async {
    final token = _lastFailedToken;
    final productId = _lastFailedProductId;
    if (token == null || productId == null) return false;

    final pending = _pendingVerifications[token];
    if (pending != null) {
      _verificationAttempts[token] = 0;
      unawaited(_verifyPurchaseOnce(token));
      return true;
    }
    return false;
  }

  /// Handles stream updates for purchases
  void _onPurchaseListUpdated(
    List<PurchaseDetails> purchaseDetailsList,
    String userId,
    VoidCallback onSubscriptionUpdated,
    void Function(String message) onPending,
    void Function(String message) onVerifying,
    void Function(String message) onSuccess,
    VoidCallback onCancelled,
    void Function(String error) onError,
  ) {
    if (purchaseDetailsList.isNotEmpty) {
      _restoreWaiter?.markPurchaseSeen();
    }

    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('Play Store Purchase pending: ${purchase.productID}');
          onPending(
            'Menunggu pembayaran, akses aktif otomatis setelah pembayaran selesai',
          );
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          onVerifying('Memverifikasi pembayaran Google Play...');
          final token = purchase.verificationData.serverVerificationData;
          if (token.isEmpty) {
            onError('Token pembelian Google Play tidak ditemukan.');
            continue;
          }
          if (_verifyingTokens.contains(token)) {
            continue; // Deduplicate in-flight token verifications
          }

          _verifyingTokens.add(token);
          _verificationAttempts[token] = 0;
          _pendingVerifications[token] = _PendingVerification(
            purchase: purchase,
            userId: userId,
            onSubscriptionUpdated: onSubscriptionUpdated,
            onVerifying: onVerifying,
            onSuccess: onSuccess,
            onError: onError,
          );
          unawaited(_verifyPurchaseOnce(token));
          break;

        case PurchaseStatus.error:
          // Cancellation by user is NOT an error
          final err = purchase.error;
          final isCancelled = err?.code == 'purchase_canceled' ||
              err?.code == 'user_canceled' ||
              (err != null && err.message.toLowerCase().contains('cancel'));
          if (isCancelled) {
            onCancelled();
          } else {
            final errMessage = err?.message ?? 'Pembelian gagal.';
            _lastError = errMessage;
            onError('Google Play Billing: $errMessage');
          }

          if (purchase.pendingCompletePurchase) {
            unawaited(_completePurchaseSafely(purchase));
          }
          break;

        case PurchaseStatus.canceled:
          onCancelled();
          if (purchase.pendingCompletePurchase) {
            unawaited(_completePurchaseSafely(purchase));
          }
          break;
      }
    }
  }

  Future<void> _completePurchaseSafely(PurchaseDetails purchase) async {
    try {
      await _iap.completePurchase(purchase);
    } catch (e) {
      debugPrint('Complete purchase notice (already acknowledged or completed): $e');
    }
  }

  static const List<Duration> _retryDelays = [
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  Future<void> _verifyPurchaseOnce(String token) async {
    final pending = _pendingVerifications[token];
    if (pending == null) return;

    _verificationTimers.remove(token)?.cancel();
    final attempt = (_verificationAttempts[token] ?? 0) + 1;
    _verificationAttempts[token] = attempt;
    _activeVerificationTokens.add(token);

    try {
      final result = await _verifyPurchase(
        purchaseToken: token,
        productId: pending.purchase.productID,
      );
      if (_pendingVerifications[token] != pending) return;

      if (result['ok'] == true) {
        final serverTimeStr = result['server_time'] as String?;
        if (serverTimeStr != null) {
          final serverTime = DateTime.tryParse(serverTimeStr);
          if (serverTime != null) {
            await TrustedTimeHelper.saveTrustedTime(pending.userId, serverTime);
          }
        }
        if (_pendingVerifications[token] != pending) return;

        pending.onSubscriptionUpdated();
        _activePurchaseDetails = pending.purchase;
        pending.onSuccess('Langganan berhasil diverifikasi.');
        if (pending.purchase.pendingCompletePurchase) {
          await _completePurchaseSafely(pending.purchase);
        }
        _clearPendingVerification(token);
        _restoreWaiter?.recordSuccess();
        return;
      }

      final isFinalFailure = _handleVerificationFailure(
        token,
        pending,
        const PlayVerifyException(
          message: 'Gagal memverifikasi langganan Google Play pada server.',
        ),
        attempt,
      );
      if (isFinalFailure &&
          pending.purchase.status == PurchaseStatus.restored) {
        _restoreWaiter?.recordFailure(message: 'Gagal memverifikasi langganan pada server.');
      }
    } catch (error) {
      if (_pendingVerifications[token] != pending) return;
      final isFinalFailure =
          _handleVerificationFailure(token, pending, error, attempt);
      if (isFinalFailure &&
          pending.purchase.status == PurchaseStatus.restored) {
        final code = error is PlayVerifyException ? error.code : null;
        final msg = error is PlayVerifyException ? error.message : error.toString();
        _restoreWaiter?.recordFailure(code: code, message: msg);
      }
    } finally {
      _activeVerificationTokens.remove(token);
    }
  }

  bool _handleVerificationFailure(
    String token,
    _PendingVerification pending,
    Object error,
    int attempt,
  ) {
    bool isPermanent = false;
    String? code;
    String message = error.toString();

    if (error is PlayVerifyException) {
      isPermanent = error.isPermanent;
      code = error.code;
      message = error.message;
    } else {
      isPermanent = const {400, 403, 409}.contains(
        error is PlayVerifyException ? error.statusCode : null,
      );
    }

    if (isPermanent || attempt >= _retryDelays.length + 1) {
      _lastFailedToken = token;
      _lastFailedProductId = pending.purchase.productID;
      pending.onError(message);
      _clearPendingVerification(token);
      _restoreWaiter?.recordFailure(code: code, message: message);
      return true;
    }

    final delay = _retryDelays[attempt - 1];
    debugPrint(
      'Play Billing verify error (attempt $attempt/${_retryDelays.length + 1}); retry scheduled in ${delay.inSeconds}s.',
    );
    pending.onVerifying(
      'Memverifikasi pembayaran Google Play... (Mencoba ulang ${attempt + 1}/${_retryDelays.length + 1})',
    );
    _verificationTimers[token] = Timer(delay, () {
      _verificationTimers.remove(token);
      unawaited(_verifyPurchaseOnce(token));
    });
    return false;
  }

  void _clearPendingVerification(String token) {
    _verificationTimers.remove(token)?.cancel();
    _verificationAttempts.remove(token);
    _pendingVerifications.remove(token);
    _verifyingTokens.remove(token);
  }

  void cancelPendingVerifications() {
    for (final timer in _verificationTimers.values) {
      timer.cancel();
    }
    _verificationTimers.clear();
    _verificationAttempts.clear();
    _pendingVerifications.clear();
    _verifyingTokens.clear();
    _activePurchaseDetails = null;
    _lastFailedToken = null;
    _lastFailedProductId = null;
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    cancelPendingVerifications();
  }
}

class _PendingVerification {
  final PurchaseDetails purchase;
  final String userId;
  final VoidCallback onSubscriptionUpdated;
  final void Function(String message) onVerifying;
  final void Function(String message) onSuccess;
  final void Function(String error) onError;

  const _PendingVerification({
    required this.purchase,
    required this.userId,
    required this.onSubscriptionUpdated,
    required this.onVerifying,
    required this.onSuccess,
    required this.onError,
  });
}

class _RestoreWaiter {
  final Completer<RestoreSummary> completer = Completer<RestoreSummary>();
  Timer? _settleTimer;
  bool _hasSeenPurchases = false;

  void markPurchaseSeen() {
    _hasSeenPurchases = true;
    _settleTimer?.cancel();
  }

  void recordSuccess() {
    _settleTimer?.cancel();
    if (!completer.isCompleted) {
      completer.complete(const RestoreSuccess());
    }
  }

  void recordFailure({String? code, required String message}) {
    _settleTimer?.cancel();
    if (!completer.isCompleted) {
      completer.complete(RestoreVerifyFailed(code: code, message: message));
    }
  }

  void checkNoPurchasesAfterDelay() {
    _settleTimer?.cancel();
    _settleTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!_hasSeenPurchases && !completer.isCompleted) {
        completer.complete(const RestoreNothingFound());
      }
    });
  }

  void dispose() {
    _settleTimer?.cancel();
  }
}
