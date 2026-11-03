import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/core/ads/services/ad_units.dart';
import 'package:buildera/core/ads/services/fake_ads_service.dart';
import 'package:buildera/core/ads/providers/ads_provider.dart';
import 'package:buildera/features/subscription/models/entitlement.dart';
import 'package:buildera/features/subscription/providers/subscription_provider.dart';

class _MockEntitlementNotifier extends EntitlementNotifier {
  final Entitlement mockEntitlement;
  _MockEntitlementNotifier(this.mockEntitlement);

  @override
  Entitlement build() => mockEntitlement;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tahap 4: AdMob Infrastructure Tests', () {
    test('AdUnits returns valid unit IDs', () {
      expect(AdUnits.bannerHero, isNotEmpty);
      expect(AdUnits.rewardedFeatures, isNotEmpty);
      expect(AdUnits.testBannerId, equals('ca-app-pub-3940256099942544/6300978111'));
      expect(AdUnits.testRewardedInterstitialId, equals('ca-app-pub-3940256099942544/5354046379'));
    });

    test('FakeAdsService lifecycle completes safely', () async {
      final service = FakeAdsService();
      expect(service.isInitialized, isFalse);

      await service.initialize();
      expect(service.isInitialized, isTrue);

      final canRequest = await service.requestConsentAndCanRequestAds();
      expect(canRequest, isTrue);

      final isPrivacyReq = await service.isPrivacyOptionsRequired();
      expect(isPrivacyReq, isFalse);
    });

    test('adsEnabledProvider disables ads for Premium entitlement', () {
      final container = ProviderContainer(
        overrides: [
          entitlementProvider.overrideWith(() => _MockEntitlementNotifier(
            Entitlement.premium(validUntil: DateTime.now().add(const Duration(days: 30))),
          )),
        ],
      );
      addTearDown(container.dispose);

      final isEnabled = container.read(adsEnabledProvider);
      expect(isEnabled, isFalse);
    });
  });
}
