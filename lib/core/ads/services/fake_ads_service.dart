import 'ads_service.dart';

class FakeAdsService implements AdsService {
  bool isInitialized = false;
  bool canRequest = true;

  @override
  Future<void> initialize() async {
    isInitialized = true;
  }

  @override
  Future<bool> requestConsentAndCanRequestAds() async {
    return canRequest;
  }

  @override
  Future<bool> isPrivacyOptionsRequired() async {
    return false;
  }

  @override
  Future<void> showPrivacyOptionsForm() async {}
}
