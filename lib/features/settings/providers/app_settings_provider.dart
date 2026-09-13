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
  static const _keyDisplayScale = 'display_scale';

  @override
  AppSettings build() {
    _loadSettings();
    return const AppSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isFull = prefs.getBool(_keyFullScreen) ?? false;
    final isCust = prefs.getBool(_keyCustomerDisplay) ?? false;
    final scale = prefs.getDouble(_keyDisplayScale) ?? 1.0;

    state = AppSettings(
      isFullScreen: isFull,
      isCustomerDisplayEnabled: isCust,
      displayScale: scale,
    );

    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    if (isDesktop) {
      await windowManager.setFullScreen(isFull);
      
      // Auto-launch customer display if enabled, BUT ONLY if we are the MAIN window
      // We detect this by checking if the 'multi_window' argument is MISSING.
      final isSecondary = Platform.executableArguments.any((a) => a.contains('multi_window'));

      if (isCust && !isSecondary) {
        // We delay slightly to ensure main window and auth state are ready
        Future.delayed(const Duration(seconds: 3), () async {
          final user = ref.read(authStateProvider).value;
          try {
            debugPrint('DEBUG: Auto-launching customer display...');
            final exePath = Platform.resolvedExecutable;
            final uid = user?.uid ?? 'unknown';
            
            if (Platform.isWindows) {
              // Use PowerShell to start a completely separate process on Windows
              await Process.run('powershell', [
                '-Command',
                'Start-Process "$exePath" -ArgumentList "multi_window", "uid=$uid"'
              ]);
            } else {
              await Process.start(
                exePath, 
                ['multi_window', 'uid=$uid'],
                mode: ProcessStartMode.detached,
              );
            }
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
    
    // ONLY launch if we are turning it ON and we are the MAIN window
    final isSecondary = Platform.executableArguments.any((a) => a.contains('multi_window'));

    if (value && !isSecondary && !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      final user = ref.read(authStateProvider).value;
      try {
        final exePath = Platform.resolvedExecutable;
        final uid = user?.uid ?? 'unknown';
        debugPrint('DEBUG: Launching customer display for UID: $uid');

        if (Platform.isWindows) {
          // Use Start-Process via PowerShell for a clean detached launch on Windows
          await Process.run('powershell', [
            '-Command',
            'Start-Process "$exePath" -ArgumentList "multi_window", "uid=$uid"'
          ]);
        } else {
          await Process.start(
            exePath, 
            ['multi_window', 'uid=$uid'],
            mode: ProcessStartMode.detached,
          );
        }
      } catch (e) {
        debugPrint('DEBUG: Failed to launch customer display: $e');
      }
    }
  }

  Future<void> setDisplayScale(double value) async {
    state = state.copyWith(displayScale: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyDisplayScale, value);
  }
}
