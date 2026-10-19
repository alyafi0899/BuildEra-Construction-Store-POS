import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../repositories/subscription_repository.dart';
import '../../../core/utils/trusted_time_helper.dart';

typedef PlayPurchaseVerifier = Future<Map<String, dynamic>> Function({
  required String purchaseToken,
  required String productId,
});

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
  String? _userId;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  String? _lastError;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => List.unmodifiable(_products);
  String? get lastError => _lastError;
  bool get isVerifying => _activeVerificationTokens.isNotEmpty;

  PlayBillingService(SubscriptionRepository repository)
      : _verifyPurchase = repository.verifyPlayPurchase;

  @visibleForTesting
  PlayBillingService.forTesting(this._verifyPurchase);

  final PlayPurchaseVerifier _verifyPurchase;

  /// Initializes Google Play Billing connection and listens to purchase events
  Future<void> initialize({
    required String userId,
    required VoidCallback onSubscriptionUpdated,
    required void Function(String error) onError,
  }) async {
    if (_userId != null && _userId != userId) {
      cancelPendingVerifications();
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
    dynamic replacementMode,
  }) async {
    if (!_isAvailable) return false;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final googleParam = GooglePlayPurchaseParam(
          productDetails: productDetails,
          applicationUserName: userId,
          changeSubscriptionParam: oldPurchaseDetails != null
              ? ChangeSubscriptionParam(
                  oldPurchaseDetails: oldPurchaseDetails as GooglePlayPurchaseDetails,
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

  /// Restores previous active purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    try {
      await _iap.restorePurchases();
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error restoring Play Store purchases: $e');
      rethrow;
    }
  }

  /// Handles stream updates for purchases
  void _onPurchaseListUpdated(
    List<PurchaseDetails> purchaseDetailsList,
    String userId,
    VoidCallback onSubscriptionUpdated,
    void Function(String error) onError,
  ) {
    for (final purchase in purchaseDetailsList) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          debugPrint('Play Store Purchase pending: ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final token = purchase.verificationData.serverVerificationData;
          if (token.isEmpty || _verifyingTokens.contains(token)) {
            continue; // Deduplicate in-flight token verifications
          }

          _verifyingTokens.add(token);
          _verificationAttempts[token] = 0;
          _pendingVerifications[token] = _PendingVerification(
            purchase: purchase,
            userId: userId,
            onSubscriptionUpdated: onSubscriptionUpdated,
            onError: onError,
          );
          unawaited(_verifyPurchaseOnce(token));
          break;

        case PurchaseStatus.error:
          // Cancellation by user is NOT an error
          final err = purchase.error;
          final isCancelled = err?.code == 'purchase_canceled' ||
              (err != null && err.message.contains('canceled'));
          if (!isCancelled) {
            final errMessage = err?.message ?? 'Pembelian gagal.';
            _lastError = errMessage;
            onError('Google Play Billing: $errMessage');
          }

          if (purchase.pendingCompletePurchase) {
            unawaited(_completePurchaseSafely(purchase));
          }
          break;

        case PurchaseStatus.canceled:
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
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 60),
    Duration(minutes: 5),
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
        if (pending.purchase.pendingCompletePurchase) {
          await _completePurchaseSafely(pending.purchase);
        }
        _clearPendingVerification(token);
        return;
      }

      _handleVerificationFailure(
        token,
        pending,
        PlayVerifyException(
          message: 'Gagal memverifikasi langganan Google Play pada server.',
        ),
        attempt,
      );
    } catch (error) {
      if (_pendingVerifications[token] != pending) return;
      _handleVerificationFailure(token, pending, error, attempt);
    } finally {
      _activeVerificationTokens.remove(token);
    }
  }

  void _handleVerificationFailure(
    String token,
    _PendingVerification pending,
    Object error,
    int attempt,
  ) {
    final isPermanent = error is PlayVerifyException &&
        const {400, 403, 409}.contains(error.statusCode);
    if (isPermanent || attempt >= _retryDelays.length + 1) {
      pending.onError('Gagal memverifikasi transaksi: $error');
      _clearPendingVerification(token);
      return;
    }

    final delay = _retryDelays[attempt - 1];
    debugPrint(
      'Play Billing verify error (attempt $attempt/5); retry scheduled.',
    );
    _verificationTimers[token] = Timer(delay, () {
      _verificationTimers.remove(token);
      unawaited(_verifyPurchaseOnce(token));
    });
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
  final void Function(String error) onError;

  const _PendingVerification({
    required this.purchase,
    required this.userId,
    required this.onSubscriptionUpdated,
    required this.onError,
  });
}
