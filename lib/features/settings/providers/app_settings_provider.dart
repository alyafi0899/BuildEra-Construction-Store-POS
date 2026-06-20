import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/app_settings.dart';

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  static const _keyFullScreen = 'is_full_screen';
  static const _keyCustomerDisplay = 'customer_display_enabled';

  @override
  AppSettings build() {
    _loadSettings();
    return const AppSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isFull = prefs.getBool(_keyFullScreen) ?? false;
    final isCust = prefs.getBool(_keyCustomerDisplay) ?? false;

    state = AppSettings(
      isFullScreen: isFull,
      isCustomerDisplayEnabled: isCust,
    );

    if (!kIsWeb) {
      await windowManager.setFullScreen(isFull);
    }
  }

  Future<void> setFullScreen(bool value) async {
    state = state.copyWith(isFullScreen: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreen, value);
    if (!kIsWeb) {
      await windowManager.setFullScreen(value);
    }
  }

  Future<void> setCustomerDisplay(bool value) async {
    state = state.copyWith(isCustomerDisplayEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCustomerDisplay, value);
  }
}
