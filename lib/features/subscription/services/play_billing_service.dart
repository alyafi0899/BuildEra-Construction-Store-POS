import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';

class PlayBillingService {
  static const String monthlyProductId = 'buildera_monthly';
  static const String yearlyProductId = 'buildera_yearly';
  static const Set<String> productIds = {monthlyProductId, yearlyProductId};

  final InAppPurchase _iap = InAppPurchase.instance;
  final SubscriptionRepository _repository;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  String? _lastError;

  bool get isAvailable => _isAvailable;
  List<ProductDetails> get products => List.unmodifiable(_products);
  String? get lastError => _lastError;

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
          onError('Error sistem Google Play Billing: $error');
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

  /// Triggers purchasing a subscription plan
  Future<bool> buySubscription(ProductDetails productDetails) async {
    if (!_isAvailable) return false;

    try {
      final purchaseParam = PurchaseParam(productDetails: productDetails);
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
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
          final verified = await _verifyAndApplyPurchase(purchase, userId);
          if (verified) {
            onSubscriptionUpdated();
          } else {
            onError('Gagal memverifikasi langganan Google Play.');
          }

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.error:
          final errMessage = purchase.error?.message ?? 'Pembelian dibatalkan atau gagal.';
          _lastError = errMessage;
          onError('Google Play Billing: $errMessage');

          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          break;
      }
    }
  }

  /// Verifies purchase details and updates subscription record in Supabase
  Future<bool> _verifyAndApplyPurchase(PurchaseDetails purchase, String userId) async {
    try {
      final plan = purchase.productID == yearlyProductId
          ? PlanType.yearly
          : PlanType.monthly;

      final now = DateTime.now();
      final duration = plan == PlanType.yearly
          ? const Duration(days: 365)
          : const Duration(days: 30);

      final subscription = Subscription(
        userId: userId,
        planType: plan,
        status: SubscriptionStatus.active,
        expiresAt: now.add(duration),
        createdAt: now,
        updatedAt: now,
        lastExternalId: purchase.purchaseID ?? purchase.productID,
      );

      await _repository.upsertSubscription(subscription);
      return true;
    } catch (e) {
      debugPrint('Error applying Play Store purchase: $e');
      return false;
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
