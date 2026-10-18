import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../repositories/subscription_repository.dart';
import '../../../core/utils/trusted_time_helper.dart';

class PlayBillingService {
  static const String monthlyProductId = 'buildera_monthly';
  static const String yearlyProductId = 'buildera_yearly';
  static const Set<String> productIds = {monthlyProductId, yearlyProductId};

  final InAppPurchase _iap = InAppPurchase.instance;
  final SubscriptionRepository _repository;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  final Set<String> _verifyingTokens = {};

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  String? _lastError;
  bool _isVerifying = false;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => List.unmodifiable(_products);
  String? get lastError => _lastError;
  bool get isVerifying => _isVerifying;

  PlayBillingService(this._repository);

  /// Initializes Google Play Billing connection and listens to purchase events
  Future<void> initialize({
    required String userId,
    required VoidCallback onSubscriptionUpdated,
    required void Function(String error) onError,
  }) async {
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
  Future<void> _onPurchaseListUpdated(
    List<PurchaseDetails> purchaseDetailsList,
    String userId,
    VoidCallback onSubscriptionUpdated,
    void Function(String error) onError,
  ) async {
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

          _isVerifying = true;
          _verifyingTokens.add(token);

          try {
            final verified = await _verifyAndApplyPurchaseWithRetry(purchase, userId);
            if (verified) {
              onSubscriptionUpdated();
              if (purchase.pendingCompletePurchase) {
                await _completePurchaseSafely(purchase);
              }
            } else {
              onError('Gagal memverifikasi langganan Google Play pada server.');
            }
          } catch (e) {
            final errStr = e.toString();
            if (errStr.contains('bound to another user')) {
              onError('Pembelian ini terikat ke akun toko lain.');
            } else {
              onError('Gagal memverifikasi transaksi: ${e.toString().replaceAll('Exception:', '')}');
            }
          } finally {
            _verifyingTokens.remove(token);
            _isVerifying = false;
          }
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
            await _completePurchaseSafely(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _completePurchaseSafely(purchase);
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

  /// Verifies purchase details with backend Edge Function with exponential backoff retry
  Future<bool> _verifyAndApplyPurchaseWithRetry(PurchaseDetails purchase, String userId) async {
    final token = purchase.verificationData.serverVerificationData;
    if (token.isEmpty) return false;

    final backoffs = [
      const Duration(seconds: 5),
      const Duration(seconds: 15),
      const Duration(seconds: 60),
      const Duration(minutes: 5),
    ];

    int attempt = 0;
    while (true) {
      try {
        final res = await _repository.verifyPlayPurchase(
          purchaseToken: token,
          productId: purchase.productID,
        );

        if (res['ok'] == true) {
          final serverTimeStr = res['server_time'] as String?;
          if (serverTimeStr != null) {
            final serverTime = DateTime.tryParse(serverTimeStr);
            if (serverTime != null) {
              await TrustedTimeHelper.saveTrustedTime(userId, serverTime);
            }
          }
          return true;
        }
        return false;
      } catch (e) {
        final isPermanent = e is PlayVerifyException &&
            (e.statusCode == 400 || e.statusCode == 403 || e.statusCode == 409);
        if (isPermanent || e.toString().contains('Pembelian ini terikat ke akun toko lain') || e.toString().contains('Pembelian tidak dapat diverifikasi')) {
          rethrow;
        }

        attempt++;
        if (attempt > backoffs.length) {
          rethrow;
        }

        debugPrint('Play Billing verify error (attempt $attempt/${backoffs.length}). Retrying in ${backoffs[attempt - 1].inSeconds}s...');
        await Future.delayed(backoffs[attempt - 1]);
      }
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
