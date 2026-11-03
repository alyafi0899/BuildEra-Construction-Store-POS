import 'package:flutter/foundation.dart';

class AdUnits {
  AdUnits._();

  /// Official Google Sample Ad Unit IDs for Debug mode
  static const String testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String testRewardedInterstitialId = 'ca-app-pub-3940256099942544/5354046379';

  /// Production Ad Unit IDs
  static const String prodBannerHeroId = 'ca-app-pub-3908012989174014/3632875164';
  static const String prodRewardedFeaturesId = 'ca-app-pub-3908012989174014/7850275592';

  /// Returns active Banner Ad Unit ID (Test ID in debug, Prod ID in release)
  static String get bannerHero {
    return kDebugMode ? testBannerId : prodBannerHeroId;
  }

  /// Returns active Rewarded Interstitial Ad Unit ID (Test ID in debug, Prod ID in release)
  static String get rewardedFeatures {
    return kDebugMode ? testRewardedInterstitialId : prodRewardedFeaturesId;
  }
}
