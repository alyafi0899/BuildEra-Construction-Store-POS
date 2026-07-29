import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../models/app_settings.dart';
import '../../auth/providers/auth_provider.dart';

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

    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      await windowManager.setFullScreen(isFull);
      
      // Auto-launch customer display if enabled
      if (isCust) {
        // We delay slightly to ensure main window and auth state are ready
        Future.delayed(const Duration(seconds: 3), () async {
          final user = ref.read(authStateProvider).value;
          try {
            await Process.start(
              Platform.resolvedExecutable, 
              ['multi_window', 'uid=${user?.uid ?? 'unknown'}'],
              mode: ProcessStartMode.detached,
            );
          } catch (e) {
            debugPrint('DEBUG: Failed to auto-launch customer display: $e');
          }
        });
      }
    }
  }

  Future<void> setFullScreen(bool value) async {
    state = state.copyWith(isFullScreen: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFullScreen, value);
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await windowManager.setFullScreen(value);
    }
  }

  Future<void> setCustomerDisplay(bool value) async {
    state = state.copyWith(isCustomerDisplayEnabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCustomerDisplay, value);
    
    if (value && !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final user = ref.read(authStateProvider).value;
      try {
        await Process.start(
          Platform.resolvedExecutable, 
          ['multi_window', 'uid=${user?.uid ?? 'unknown'}'],
          mode: ProcessStartMode.detached,
        );
      } catch (e) {
        debugPrint('DEBUG: Failed to launch customer display: $e');
      }
    }
  }
}
