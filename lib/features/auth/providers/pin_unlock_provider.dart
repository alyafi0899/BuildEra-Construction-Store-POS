import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages the session-based lock state of the app.
/// This state is NOT persistent - it resets to 'locked' (false) on every app start.
class PinUnlockNotifier extends Notifier<bool> {
  Timer? _autoLockTimer;
  static const _lockDuration = Duration(minutes: 30);

  @override
  bool build() {
    ref.onDispose(() => _autoLockTimer?.cancel());
    return false;
  }

  void unlock() {
    state = true;
    _resetTimer();
  }

  void lock() {
    _autoLockTimer?.cancel();
    state = false;
  }

  /// Called whenever user interacts with the app to postpone auto-lock
  void recordActivity() {
    if (state) {
      _resetTimer();
    }
  }

  void _resetTimer() {
    _autoLockTimer?.cancel();
    _autoLockTimer = Timer(_lockDuration, () {
      state = false;
    });
  }
}

final pinUnlockProvider = NotifierProvider<PinUnlockNotifier, bool>(PinUnlockNotifier.new);
