import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:buildera/features/subscription/models/subscription.dart';
import 'package:buildera/features/subscription/models/subscription_history.dart';
import 'package:buildera/features/subscription/presentation/widgets/subscription_diagnostics_dialog.dart';
import 'package:buildera/features/subscription/providers/subscription_provider.dart';
import 'package:buildera/features/subscription/repositories/subscription_repository.dart';

class _MockSubscriptionRepository implements SubscriptionRepository {
  @override
  Future<Subscription?> getSubscription(String userId) async {
    return Subscription(
      userId: userId,
      planType: PlanType.monthly,
      status: SubscriptionStatus.active,
      expiresAt: DateTime.utc(2026, 12, 31),
      gracePeriodEndsAt: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      lastExternalId: 'order-12345',
    );
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
  Future<Map<String, dynamic>?> syncPlaySubscription() async => {'ok': true};

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
  testWidgets('SubscriptionDiagnosticsDialog displays mock subscription values correctly',
      (tester) async {
    final mockSub = Subscription(
      userId: 'test-user',
      planType: PlanType.monthly,
      status: SubscriptionStatus.active,
      expiresAt: DateTime.utc(2026, 12, 31, 23, 59, 59),
      gracePeriodEndsAt: null,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
      lastExternalId: 'GPA.1234-5678-9012-34567',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          subscriptionRepositoryProvider
              .overrideWithValue(_MockSubscriptionRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SubscriptionDiagnosticsDialog(currentSub: mockSub),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Diagnosa Status Langganan'), findsOneWidget);
    expect(find.text('DATABASE STATUS (DB)'), findsOneWidget);
    expect(find.text('WAKTU TERPERCAYA (TRUSTED TIME)'), findsOneWidget);
    expect(find.text('ENTITLEMENT (SINGLE SOURCE)'), findsOneWidget);
    expect(find.text('GPA.1234-5678-9012-34567'), findsOneWidget);
    expect(find.text('SEGARKAN SEKARANG'), findsOneWidget);

    // Tap Segarkan sekarang button
    await tester.tap(find.text('SEGARKAN SEKARANG'));
    await tester.pumpAndSettle();

    expect(find.text('Sukses (terverifikasi)'), findsOneWidget);
  });
}
