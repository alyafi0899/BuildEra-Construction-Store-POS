abstract class AdsService {
  Future<void> initialize();
  Future<bool> requestConsentAndCanRequestAds();
  Future<bool> isPrivacyOptionsRequired();
  Future<void> showPrivacyOptionsForm();
}
