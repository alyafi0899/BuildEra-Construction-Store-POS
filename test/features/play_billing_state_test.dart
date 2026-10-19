import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_platform_interface/in_app_purchase_platform_interface.dart';

import 'package:buildera/features/auth/models/auth_user.dart';
import 'package:buildera/features/auth/providers/auth_provider.dart';
import 'package:buildera/features/subscription/models/subscription.dart';
import 'package:buildera/features/subscription/providers/subscription_provider.dart';
import 'package:buildera/features/subscription/services/play_billing_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakePurchasePlatform purchasePlatform;
  late TargetPlatform? previousTargetPlatform;
  late List<PlayBillingService> services;
  final containers = <ProviderContainer>[];

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
    for (final container in containers) {
      container.dispose();
    }
    containers.clear();
    for (final service in services) {
      service.dispose();
    }
    debugDefaultTargetPlatformOverride = previousTargetPlatform;
    await purchasePlatform.controller.close();
  });

  PlayBillingService createService(
    Future<Map<String, dynamic>> Function(String, String) verify,
  ) {
    final service = PlayBillingService.forTesting(
      ({required purchaseToken, required productId}) =>
          verify(purchaseToken, productId),
    );
    services.add(service);
    return service;
  }

  Future<void> initialize(PlayBillingService service) {
    return service.initialize(
      userId: 'user-id',
      onSubscriptionUpdated: () {},
      onPending: (_) {},
      onVerifying: (_) {},
      onSuccess: (_) {},
      onCancelled: () {},
      onError: fail,
    );
  }

  Future<ProviderContainer> createContainer(
    PlayBillingService service,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith(
          _TestAuthNotifier.new,
        ),
        subscriptionStateProvider.overrideWith(_TestSubscriptionNotifier.new),
        playBillingServiceProvider.overrideWithValue(service),
      ],
    );
    containers.add(container);
    container.read(authStateProvider.notifier).state = const AsyncValue.data(
      AuthUser(
        uid: 'user-id',
        email: 'user@example.com',
        isEmailVerified: true,
      ),
    );
    return container;
  }

  test('failed buy updates billing UI instead of leaving it pending', () async {
    purchasePlatform.buyResult = false;
    final service = createService((_, __) async => {'ok': true});
    await initialize(service);
    final container = await createContainer(service);

    final result = await container
        .read(subscriptionStateProvider.notifier)
        .buyPlayStoreSubscription(
            _product(PlayBillingService.monthlyProductId));

    expect(result, isFalse);
    expect(
      container.read(billingUiStateProvider).status,
      BillingUiStatus.error,
    );
    expect(
      container.read(billingUiStateProvider).message,
      isNot(contains('Memproses pembelian')),
    );
  });

  test('restore waits for restored purchase verification from the stream',
      () async {
    final verification = Completer<Map<String, dynamic>>();
    final service = createService((_, __) => verification.future);
    await initialize(service);

    var restored = false;
    final restore = service
        .restorePurchases(timeout: const Duration(seconds: 2))
        .then((_) => restored = true);
    await Future<void>.delayed(Duration.zero);
    expect(restored, isFalse);

    purchasePlatform.controller.add([
      _purchase(
        'restore-token',
        productId: PlayBillingService.monthlyProductId,
        status: PurchaseStatus.restored,
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(restored, isFalse);

    verification.complete({'ok': true});
    await restore;
    expect(restored, isTrue);
    expect(service.activePurchaseDetails?.productID,
        PlayBillingService.monthlyProductId);
  });

  test('purchase stream reports pending, verifying, success, and silent cancel',
      () async {
    final service = createService((_, __) async => {'ok': true});
    final transitions = <String>[];
    await service.initialize(
      userId: 'user-id',
      onSubscriptionUpdated: () {},
      onPending: transitions.add,
      onVerifying: (_) => transitions.add('verifying'),
      onSuccess: (_) => transitions.add('success'),
      onCancelled: () => transitions.add('cancelled'),
      onError: transitions.add,
    );

    purchasePlatform.controller.add([
      _purchase(
        'pending-token',
        productId: PlayBillingService.monthlyProductId,
        status: PurchaseStatus.pending,
      ),
    ]);
    purchasePlatform.controller.add([
      _purchase(
        'cancel-token',
        productId: PlayBillingService.monthlyProductId,
        status: PurchaseStatus.error,
      )..error = IAPError(
          source: 'Google Play',
          code: 'purchase_canceled',
          message: 'User canceled the purchase.',
        ),
    ]);
    purchasePlatform.controller.add([
      _purchase(
        'success-token',
        productId: PlayBillingService.monthlyProductId,
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(
      transitions,
      [
        'Menunggu pembayaran, akses aktif otomatis setelah pembayaran selesai',
        'cancelled',
        'verifying',
        'success',
      ],
    );
  });

  test('upgrade and downgrade send the active Play purchase and typed mode',
      () async {
    final service = createService((_, __) async => {'ok': true});
    await initialize(service);
    final container = await createContainer(service);

    final monthly = _purchase(
      'monthly-token',
      productId: PlayBillingService.monthlyProductId,
    );
    purchasePlatform.controller.add([monthly]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final upgradeResult = await container
        .read(subscriptionStateProvider.notifier)
        .buyPlayStoreSubscription(_product(PlayBillingService.yearlyProductId));
    expect(upgradeResult, isTrue);
    final upgradeParam =
        purchasePlatform.purchaseParams.last as GooglePlayPurchaseParam;
    expect(upgradeParam.changeSubscriptionParam?.oldPurchaseDetails,
        same(monthly));
    expect(
      upgradeParam.changeSubscriptionParam?.replacementMode,
      ReplacementMode.withTimeProration,
    );

    final yearly = _purchase(
      'yearly-token',
      productId: PlayBillingService.yearlyProductId,
    );
    purchasePlatform.controller.add([yearly]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final downgradeResult = await container
        .read(subscriptionStateProvider.notifier)
        .buyPlayStoreSubscription(
            _product(PlayBillingService.monthlyProductId));
    expect(downgradeResult, isTrue);
    final downgradeParam =
        purchasePlatform.purchaseParams.last as GooglePlayPurchaseParam;
    expect(downgradeParam.changeSubscriptionParam?.oldPurchaseDetails,
        same(yearly));
    expect(
      downgradeParam.changeSubscriptionParam?.replacementMode,
      ReplacementMode.deferred,
    );
  });

  test('same active package is blocked with a clear error', () async {
    final service = createService((_, __) async => {'ok': true});
    await initialize(service);
    final container = await createContainer(service);

    purchasePlatform.controller.add([
      _purchase(
        'monthly-token',
        productId: PlayBillingService.monthlyProductId,
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final result = await container
        .read(subscriptionStateProvider.notifier)
        .buyPlayStoreSubscription(
            _product(PlayBillingService.monthlyProductId));

    expect(result, isFalse);
    expect(purchasePlatform.purchaseParams, isEmpty);
    final state = container.read(billingUiStateProvider);
    expect(state.status, BillingUiStatus.error);
    expect(state.message, contains('sudah aktif'));
  });

  test('manage subscription URL includes product and Android application ID',
      () {
    expect(
      PlayBillingService.manageSubscriptionUri(
        PlayBillingService.yearlyProductId,
      ).toString(),
      'https://play.google.com/store/account/subscriptions?sku=buildera_yearly&package=com.solutivostudio.caltax',
    );
  });
}

ProductDetails _product(String id) => ProductDetails(
      id: id,
      title: id,
      description: id,
      price: 'Rp 100.000',
      rawPrice: 100000,
      currencyCode: 'IDR',
    );

GooglePlayPurchaseDetails _purchase(
  String token, {
  required String productId,
  PurchaseStatus status = PurchaseStatus.purchased,
}) {
  return GooglePlayPurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: token,
      serverVerificationData: token,
      source: 'Google Play',
    ),
    transactionDate: null,
    billingClientPurchase: PurchaseWrapper(
      orderId: 'order-$token',
      packageName: PlayBillingService.androidApplicationId,
      purchaseTime: 1,
      purchaseToken: token,
      signature: '',
      products: [productId],
      isAutoRenewing: true,
      originalJson: '{}',
      isAcknowledged: false,
      purchaseState: PurchaseStateWrapper.purchased,
    ),
    status: status,
  );
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  AsyncValue<Subscription?> build() => const AsyncValue.data(null);
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  Stream<AuthUser?> build() => const Stream.empty();
}

class _FakePurchasePlatform extends InAppPurchasePlatform {
  final StreamController<List<PurchaseDetails>> controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<PurchaseParam> purchaseParams = [];
  bool buyResult = true;

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
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    purchaseParams.add(purchaseParam);
    return buyResult;
  }

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {}

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}
}
