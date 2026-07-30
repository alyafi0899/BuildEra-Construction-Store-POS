import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BarcodeScannerState {
  final String buffer;
  final bool isProcessing;
  final DateTime? lastKeyTime;
  final bool isValidSpeed;

  const BarcodeScannerState({
    this.buffer = '',
    this.isProcessing = false,
    this.lastKeyTime,
    this.isValidSpeed = true,
  });

  BarcodeScannerState copyWith({
    String? buffer,
    bool? isProcessing,
    DateTime? lastKeyTime,
    bool? isValidSpeed,
  }) =>
      BarcodeScannerState(
        buffer: buffer ?? this.buffer,
        isProcessing: isProcessing ?? this.isProcessing,
        lastKeyTime: lastKeyTime ?? this.lastKeyTime,
        isValidSpeed: isValidSpeed ?? this.isValidSpeed,
      );
}

class BarcodeScannerNotifier extends Notifier<BarcodeScannerState> {
  Timer? _debounceTimer;
  static const int _maxHumanKeyIntervalMs = 60; // Standard scanner is < 20ms
  
  @override
  BarcodeScannerState build() => const BarcodeScannerState();

  bool onKeyEvent(KeyEvent event, {required Function(String) onComplete}) {
    if (event is! KeyDownEvent) return false;
    if (state.isProcessing) return false;

    final now = DateTime.now();
    final logicalKey = event.logicalKey;

    // 1. Check speed if buffer isn't empty
    bool currentKeyIsFast = true;
    if (state.buffer.isNotEmpty && state.lastKeyTime != null) {
      final interval = now.difference(state.lastKeyTime!).inMilliseconds;
      if (interval > _maxHumanKeyIntervalMs) {
        currentKeyIsFast = false;
      }
    }

    // 2. Manual completion via Enter or Tab
    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.tab) {
      if (state.buffer.isNotEmpty && state.isValidSpeed) {
        _debounceTimer?.cancel();
        final finalBarcode = state.buffer;
        
        state = state.copyWith(isProcessing: true);
        onComplete(finalBarcode);
        state = const BarcodeScannerState();
        return true;
      }
      clearBuffer();
      return false;
    }

    // 3. Ignore non-character keys
    if (_isModifierKey(logicalKey) || _isFunctionalKey(logicalKey)) return false;

    // 4. Extract character
    final char = _extractChar(event);
    if (char == null) return false;

    // 5. Update buffer and speed state
    state = state.copyWith(
      buffer: state.buffer + char,
      lastKeyTime: now,
      isValidSpeed: state.buffer.isEmpty ? true : (state.isValidSpeed && currentKeyIsFast),
    );

    // 6. Auto-completion logic
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      if (state.buffer.isNotEmpty && !state.isProcessing) {
        if (state.isValidSpeed && state.buffer.length >= 3) {
          final finalBarcode = state.buffer;
          state = state.copyWith(isProcessing: true);
          onComplete(finalBarcode);
          state = const BarcodeScannerState();
        } else {
          clearBuffer();
        }
      }
    });

    return false;
  }

  void clearBuffer() {
    _debounceTimer?.cancel();
    state = const BarcodeScannerState();
  }

  bool _isModifierKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.controlLeft ||
        key == LogicalKeyboardKey.controlRight ||
        key == LogicalKeyboardKey.altLeft ||
        key == LogicalKeyboardKey.altRight ||
        key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }

  bool _isFunctionalKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.capsLock ||
        key == LogicalKeyboardKey.numLock ||
        key == LogicalKeyboardKey.scrollLock ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.escape ||
        key.keyLabel.contains('F') && key.keyLabel.length <= 3;
  }

  String? _extractChar(KeyEvent event) {
    final char = event.character;
    if (char == null || char.isEmpty) return null;
    final codeUnit = char.codeUnitAt(0);
    if (codeUnit < 32 || codeUnit == 127) return null;
    return char;
  }
}

final barcodeScannerProvider =
    NotifierProvider<BarcodeScannerNotifier, BarcodeScannerState>(
        BarcodeScannerNotifier.new);
