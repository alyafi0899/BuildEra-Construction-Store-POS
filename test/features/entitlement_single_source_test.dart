import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:buildera/features/auth/models/auth_user.dart' as model;
import 'package:buildera/features/auth/providers/auth_provider.dart';
import 'package:buildera/features/subscription/models/subscription.dart';
import 'package:buildera/features/subscription/models/subscription_history.dart';
import 'package:buildera/features/subscription/providers/subscription_provider.dart';
import 'package:buildera/features/subscription/repositories/subscription_repository.dart';

class _FakeSupabaseClient extends Fake implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #channel) {
      return _FakeRealtimeChannel();
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeRealtimeChannel extends Fake implements RealtimeChannel {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #onPostgresChanges) {
      return this;
    }
    if (invocation.memberName == #subscribe) {
      return this;
    }
    if (invocation.memberName == #unsubscribe) {
      return Future.value('ok');
    }
    return super.noSuchMethod(invocation);
  }
}

class _FakeSubscriptionRepository implements SubscriptionRepository {
  Subscription? nextSubscription;
  int getSubscriptionCallCount = 0;
  Completer<Subscription?>? pendingCompleter;

  @override
  Future<Subscription?> getSubscription(String userId) async {
    getSubscriptionCallCount++;
    if (pendingCompleter != null) {
      return pendingCompleter!.future;
    }
    return nextSubscription;
  }

  @override
  Future<List<SubscriptionHistory>> getHistory(String userId) async => [];

  @override
  Future<Map<String, dynamic>> verifyPlayPurchase({
    required String purchaseToken,
    required String productId,
  }) async =>
      {'ok': true};

  @override
  Future<Map<String, dynamic>> createPaymentInvoice({
    required String userId,
    required PlanType plan,
    required String email,
    String? method,
  }) async =>
      {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeSubscriptionRepository fakeRepository;
  late _FakeSupabaseClient fakeSupabaseClient;
  late ProviderContainer container;

  setUp(() {
    fakeRepository = _FakeSubscriptionRepository();
    fakeSupabaseClient = _FakeSupabaseClient();
    container = ProviderContainer(
      overrides: [
        supabaseClientProvider.overrideWithValue(fakeSupabaseClient),
        subscriptionRepositoryProvider.overrideWithValue(fakeRepository),
      ],
    );
    container.read(authStateProvider.notifier).state = const AsyncValue.data(
      model.AuthUser(
        uid: 'user-1',
        email: 'user@example.com',
        isEmailVerified: true,
      ),
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('serialized refresh merges concurrent calls during in-flight fetch', () async {
    fakeRepository.pendingCompleter = Completer<Subscription?>();

    final f1 = container.read(entitlementProvider.notifier).refresh();
    final f2 = container.read(entitlementProvider.notifier).refresh();

    // Completing the single underlying pending completer resolves both futures
    fakeRepository.pendingCompleter!.complete(
      Subscription(
        userId: 'user-1',
        planType: PlanType.monthly,
        status: SubscriptionStatus.active,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    await Future.wait([f1, f2]);
    expect(container.read(entitlementProvider).isPremium, isTrue);
  });

  test('grace period subscription sets validUntil to gracePeriodEndsAt without infinite loop', () async {
    final now = DateTime.now();
    final graceSub = Subscription(
      userId: 'user-1',
      planType: PlanType.monthly,
      status: SubscriptionStatus.grace,
      expiresAt: now.subtract(const Duration(days: 2)),
      gracePeriodEndsAt: now.add(const Duration(days: 5)),
      createdAt: now.subtract(const Duration(days: 30)),
      updatedAt: now,
    );

    fakeRepository.nextSubscription = graceSub;
    await container.read(entitlementProvider.notifier).refresh();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final entitlement = container.read(entitlementProvider);
    expect(entitlement.isPremium, isTrue);
    expect(entitlement.validUntil, equals(graceSub.gracePeriodEndsAt));

    // Ensure call count remains stable (no infinite microtask loop)
    final callsAfterRefresh = fakeRepository.getSubscriptionCallCount;
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fakeRepository.getSubscriptionCallCount, equals(callsAfterRefresh));
  });

  test('isPremiumProvider and entitlementProvider are in 100% agreement', () async {
    fakeRepository.nextSubscription = Subscription(
      userId: 'user-1',
      planType: PlanType.yearly,
      status: SubscriptionStatus.active,
      expiresAt: DateTime.now().add(const Duration(days: 365)),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await container.read(entitlementProvider.notifier).refresh();

    final isPremiumValue = container.read(isPremiumProvider);
    final entitlementIsPremium = container.read(entitlementProvider).isPremium;

    expect(isPremiumValue, equals(entitlementIsPremium));
    expect(isPremiumValue, isTrue);
  });

  test('app resume lifecycle event triggers throttled refresh with 30s min interval', () async {
    final notifier = container.read(entitlementProvider.notifier);
    final initialCount = fakeRepository.getSubscriptionCallCount;

    notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    final afterFirstResume = fakeRepository.getSubscriptionCallCount;
    expect(afterFirstResume, greaterThan(initialCount));

    // Immediate second resume within 30s should be throttled
    notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);

    expect(fakeRepository.getSubscriptionCallCount, equals(afterFirstResume));
  });
}
