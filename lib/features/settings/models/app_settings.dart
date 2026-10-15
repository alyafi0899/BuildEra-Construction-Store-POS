import '../../../core/localization/app_language.dart';

class AppSettings {
  final bool isFullScreen;
  final bool isCustomerDisplayEnabled;
  final double displayScale;
  final AppLanguage appLanguage;

  const AppSettings({
    this.isFullScreen = false,
    this.isCustomerDisplayEnabled = false,
    this.displayScale = 1.0,
    this.appLanguage = AppLanguage.indonesian,
  });

  AppSettings copyWith({
    bool? isFullScreen,
    bool? isCustomerDisplayEnabled,
    double? displayScale,
    AppLanguage? appLanguage,
  }) {
    return AppSettings(
      isFullScreen: isFullScreen ?? this.isFullScreen,
      isCustomerDisplayEnabled: isCustomerDisplayEnabled ?? this.isCustomerDisplayEnabled,
      displayScale: displayScale ?? this.displayScale,
      appLanguage: appLanguage ?? this.appLanguage,
    );
  }
}
