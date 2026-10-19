import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:buildera/features/settings/presentation/pages/settings_page.dart';
import 'package:buildera/features/subscription/models/subscription.dart';
import 'package:buildera/features/subscription/providers/subscription_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
  final launchedUrls = <String>[];

  setUp(() {
    launchedUrls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, (call) async {
      if (call.method == 'launch') {
        launchedUrls
            .add((call.arguments as Map<Object?, Object?>)['url']! as String);
        return true;
      }
      return false;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(urlLauncherChannel, null);
  });

  testWidgets('active Play subscription shows warning and opens its Play URL',
      (tester) async {
    await _withAndroidPlatform(() async {
      await _pumpDialog(tester, _subscription(SubscriptionStatus.active));

      expect(
        find.text(
          'Langganan Google Play tidak berhenti otomatis saat akun dihapus. Batalkan di Play Store agar tidak ditagih.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Kelola langganan'));
      await tester.pumpAndSettle();

      expect(
        launchedUrls,
        [
          'https://play.google.com/store/account/subscriptions?sku=buildera_monthly&package=com.solutivostudio.caltax',
        ],
      );
    });
  });

  testWidgets('free and expired subscriptions do not show deletion warning',
      (tester) async {
    await _withAndroidPlatform(() async {
      for (final subscription in [
        Subscription.free('user-id'),
        _subscription(SubscriptionStatus.expired),
      ]) {
        await _pumpDialog(tester, subscription);
        expect(
          find.text(
            'Langganan Google Play tidak berhenti otomatis saat akun dihapus. Batalkan di Play Store agar tidak ditagih.',
          ),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}

Future<void> _withAndroidPlatform(Future<void> Function() run) async {
  final previousTargetPlatform = debugDefaultTargetPlatformOverride;
  debugDefaultTargetPlatformOverride = TargetPlatform.android;
  try {
    await run();
  } finally {
    debugDefaultTargetPlatformOverride = previousTargetPlatform;
  }
}

Future<void> _pumpDialog(
  WidgetTester tester,
  Subscription? subscription,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        subscriptionStateProvider.overrideWith(
          () => _FixedSubscriptionNotifier(subscription),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SupportAndPrivacyDialog(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Subscription _subscription(SubscriptionStatus status) => Subscription(
      userId: 'user-id',
      planType: PlanType.monthly,
      status: status,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

class _FixedSubscriptionNotifier extends SubscriptionNotifier {
  final Subscription? subscription;

  _FixedSubscriptionNotifier(this.subscription);

  @override
  AsyncValue<Subscription?> build() => AsyncValue.data(subscription);
}
