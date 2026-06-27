import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final scanModeProvider =
    NotifierProvider<ScanModeNotifier, bool>(ScanModeNotifier.new);

class ScanModeNotifier extends Notifier<bool> {
  static const _key = 'scan_mode_auto_add';

  @override
  bool build() {
    _load();
    return true; // Default to Jual Langsung
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}
