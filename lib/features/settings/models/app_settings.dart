class AppSettings {
  final bool isFullScreen;
  final bool isCustomerDisplayEnabled;

  const AppSettings({
    this.isFullScreen = false,
    this.isCustomerDisplayEnabled = false,
  });

  AppSettings copyWith({
    bool? isFullScreen,
    bool? isCustomerDisplayEnabled,
  }) {
    return AppSettings(
      isFullScreen: isFullScreen ?? this.isFullScreen,
      isCustomerDisplayEnabled: isCustomerDisplayEnabled ?? this.isCustomerDisplayEnabled,
    );
  }
}
