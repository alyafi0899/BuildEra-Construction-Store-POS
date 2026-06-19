import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/app_settings.dart';

import '../../cashier/providers/cart_provider.dart';
import '../../cashier/providers/customer_display_provider.dart';

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
      if (isCust) {
        // Delay slightly to ensure primary window is ready
        Future.delayed(const Duration(seconds: 2), () => _openCustomerWindow());
      }
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
    
    if (!kIsWeb) {
      if (value) {
        await _openCustomerWindow();
      } else {
        // User can close it manually or it will close on app restart
      }
    }
  }

  Future<void> _openCustomerWindow() async {
    try {
      final subWindowIds = await DesktopMultiWindow.getAllSubWindowIds();
      if (subWindowIds.isNotEmpty) return; // Already open

      final window = await DesktopMultiWindow.createWindow('{}');
      window
        ..setFrame(const Offset(0, 0) & const Size(1280, 720))
        ..center()
        ..setTitle('Tampilan Pelanggan - KONSTRUKSI POS')
        ..show();

      // Give the window time to initialize its listener
      Future.delayed(const Duration(seconds: 3), () {
        final currentCart = ref.read(cartProvider);
        CustomerDisplayBridge.broadcastCart(currentCart);
      });
    } catch (e) {
      debugPrint('Error opening customer window: $e');
    }
  }
}
