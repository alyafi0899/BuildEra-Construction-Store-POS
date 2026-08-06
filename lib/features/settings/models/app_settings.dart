class AppSettings {
  final bool isFullScreen;
  final bool isCustomerDisplayEnabled;
  final double displayScale;

  const AppSettings({
    this.isFullScreen = false,
    this.isCustomerDisplayEnabled = false,
    this.displayScale = 1.0,
  });

  AppSettings copyWith({
    bool? isFullScreen,
    bool? isCustomerDisplayEnabled,
    double? displayScale,
  }) {
    return AppSettings(
      isFullScreen: isFullScreen ?? this.isFullScreen,
      isCustomerDisplayEnabled: isCustomerDisplayEnabled ?? this.isCustomerDisplayEnabled,
      displayScale: displayScale ?? this.displayScale,
    );
  }
}
