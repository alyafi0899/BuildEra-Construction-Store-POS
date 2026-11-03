import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'ads_service.dart';

class GoogleAdsService implements AdsService {
  bool _isInitialized = false;

  bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> initialize() async {
    if (!isSupportedPlatform || _isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
    } catch (e) {
      debugPrint('GoogleAdsService initialize notice: $e');
    }
  }

  @override
  Future<bool> requestConsentAndCanRequestAds() async {
    if (!isSupportedPlatform) return false;

    final completer = Completer<bool>();

    try {
      final params = ConsentRequestParameters();
      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
              if (formError != null) {
                debugPrint('ConsentForm error: ${formError.message}');
              }
              final canRequest = await ConsentInformation.instance.canRequestAds();
              if (canRequest) {
                await initialize();
              }
              if (!completer.isCompleted) completer.complete(canRequest);
            });
          } catch (e) {
            final canRequest = await ConsentInformation.instance.canRequestAds();
            if (!completer.isCompleted) completer.complete(canRequest);
          }
        },
        (FormError error) async {
          debugPrint('ConsentInfoUpdate error: ${error.message}');
          final canRequest = await ConsentInformation.instance.canRequestAds();
          if (!completer.isCompleted) completer.complete(canRequest);
        },
      );
    } catch (e) {
      debugPrint('Consent exception: $e');
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future;
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    if (!isSupportedPlatform) return false;
    try {
      final status = await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showPrivacyOptionsForm() async {
    if (!isSupportedPlatform) return;
    try {
      ConsentForm.showPrivacyOptionsForm((formError) {
        if (formError != null) {
          debugPrint('PrivacyOptionsForm error: ${formError.message}');
        }
      });
    } catch (e) {
      debugPrint('showPrivacyOptionsForm notice: $e');
    }
  }
}
