import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/subscription/providers/subscription_provider.dart';
import '../services/ads_service.dart';
import '../services/google_ads_service.dart';
import '../services/fake_ads_service.dart';

final adsServiceProvider = Provider<AdsService>((ref) {
  if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
    return FakeAdsService();
  }
  return GoogleAdsService();
});

final adsEnabledProvider = Provider<bool>((ref) {
  // Desktop / Web check
  if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
    return false;
  }

  final entitlement = ref.watch(entitlementProvider);

  // Free tier only
  if (entitlement.isPremium) {
    return false;
  }

  return true;
});
