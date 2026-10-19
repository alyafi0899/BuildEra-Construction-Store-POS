import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'package:buildera/features/subscription/repositories/subscription_repository.dart';
import 'package:buildera/features/subscription/services/play_billing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePurchasePlatform purchasePlatform;
  late TargetPlatform? previousTargetPlatform;
  late List<PlayBillingService> services;

  setUp(() {
    services = [];
    previousTargetPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    InAppPurchase.instance;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    purchasePlatform = _FakePurchasePlatform();
    InAppPurchasePlatform.instance = purchasePlatform;
  });

  tearDown(() async {
    for (final service in services) {
      service.dispose();
    }
    debugDefaultTargetPlatformOverride = previousTargetPlatform;
    await purchasePlatform.controller.close();
  });

  test('purchase stream starts separate verifications without waiting', () {
    fakeAsync((async) {
      final firstResponse = Completer<Map<String, dynamic>>();
      final calls = <String>[];
      final service = PlayBillingService.forTesting(
        ({required purchaseToken, required productId}) {
          calls.add(purchaseToken);
          return purchaseToken == 'token-1'
              ? firstResponse.future
              : Future.value({'ok': true});
        },
      );
      services.add(service);
      var updates = 0;
      final errors = <String>[];

      unawaited(
        service.initialize(
          userId: 'user',
          onSubscriptionUpdated: () => updates++,
          onError: errors.add,
        ),
      );
      async.flushMicrotasks();

      final first = _purchase('token-1');
      final second = _purchase('token-2');
      purchasePlatform.controller.add([first, second]);
      async.flushMicrotasks();

      expect(calls, ['token-1', 'token-2']);
      expect(updates, 1);
      expect(purchasePlatform.completedPurchases, [second]);
      expect(errors, isEmpty);

      firstResponse.complete({'ok': true});
      async.flushMicrotasks();
      expect(updates, 2);
      expect(purchasePlatform.completedPurchases, [second, first]);

      service.dispose();
    });
  });

  test('permanent 4xx verification failure is not retried', () {
    fakeAsync((async) {
      final calls = <String>[];
      final service = PlayBillingService.forTesting(
        ({required purchaseToken, required productId}) {
          calls.add(purchaseToken);
          return Future.error(
            const PlayVerifyException(statusCode: 400, message: 'invalid'),
          );
        },
      );
      services.add(service);
      final errors = <String>[];

      unawaited(
        service.initialize(
          userId: 'user',
          onSubscriptionUpdated: () {},
          onError: errors.add,
        ),
      );
      async.flushMicrotasks();
      purchasePlatform.controller.add([_purchase('token-4xx')]);
      async.flushMicrotasks();

      expect(calls, ['token-4xx']);
      expect(errors, hasLength(1));

      async.elapse(const Duration(minutes: 6));
      async.flushMicrotasks();
      expect(calls, ['token-4xx']);
      service.dispose();
    });
  });

  test('successful retry completes the purchase once', () {
    fakeAsync((async) {
      var calls = 0;
      final service = PlayBillingService.forTesting(
        ({required purchaseToken, required productId}) {
          calls++;
          if (calls == 1) {
            return Future.error(
              const PlayVerifyException(statusCode: 503, message: 'retry'),
            );
          }
          return Future.value({'ok': true});
        },
      );
      services.add(service);
      final purchase = _purchase('token-retry');
      var updates = 0;

      unawaited(
        service.initialize(
          userId: 'user',
          onSubscriptionUpdated: () => updates++,
          onError: fail,
        ),
      );
      async.flushMicrotasks();
      purchasePlatform.controller.add([purchase]);
      async.flushMicrotasks();

      expect(calls, 1);
      expect(purchasePlatform.completedPurchases, isEmpty);

      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();

      expect(calls, 2);
      expect(updates, 1);
      expect(purchasePlatform.completedPurchases, [purchase]);

      async.elapse(const Duration(minutes: 6));
      async.flushMicrotasks();
      expect(calls, 2);
      expect(purchasePlatform.completedPurchases, [purchase]);
      service.dispose();
    });
  });
}

PurchaseDetails _purchase(String token) {
  return PurchaseDetails(
    productID: PlayBillingService.monthlyProductId,
    verificationData: PurchaseVerificationData(
      localVerificationData: token,
      serverVerificationData: token,
      source: 'Google Play',
    ),
    transactionDate: null,
    status: PurchaseStatus.purchased,
  )..pendingCompletePurchase = true;
}

class _FakePurchasePlatform extends InAppPurchasePlatform {
  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<PurchaseDetails> completedPurchases = [];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) {
    return Future.value(
      ProductDetailsResponse(productDetails: [], notFoundIDs: []),
    );
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completedPurchases.add(purchase);
  }
}
