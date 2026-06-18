import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BarcodeScannerState {
  final String buffer;
  final bool isProcessing;

  const BarcodeScannerState({
    this.buffer = '',
    this.isProcessing = false,
  });

  BarcodeScannerState copyWith({
    String? buffer,
    bool? isProcessing,
  }) =>
      BarcodeScannerState(
        buffer: buffer ?? this.buffer,
        isProcessing: isProcessing ?? this.isProcessing,
      );
}

class BarcodeScannerNotifier extends Notifier<BarcodeScannerState> {
  Timer? _debounceTimer;
  
  @override
  BarcodeScannerState build() => const BarcodeScannerState();

  /// Processes key events. 
  /// Returns true if a barcode completion was triggered by a terminator (Enter/Tab).
  bool onKeyEvent(KeyEvent event, {required Function(String) onComplete}) {
    if (event is! KeyDownEvent) return false;
    if (state.isProcessing) return false;

    final logicalKey = event.logicalKey;

    // 1. Manual completion via Enter or Tab
    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.tab) {
      if (state.buffer.isNotEmpty) {
        _debounceTimer?.cancel();
        final finalBarcode = state.buffer;
        
        state = state.copyWith(isProcessing: true);
        onComplete(finalBarcode);
        state = const BarcodeScannerState();
        return true;
      }
      return false;
    }

    // 2. Ignore non-character keys
    if (_isModifierKey(logicalKey) || _isFunctionalKey(logicalKey)) return false;

    // 3. Extract character
    final char = _extractChar(event);
    if (char == null) return false;

    // 4. Update buffer
    state = state.copyWith(buffer: state.buffer + char);

    // 5. Auto-completion logic (Fallback for scanners without Enter suffix)
    // Increased to 200ms to handle potential OS/Hardware lag
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (state.buffer.isNotEmpty && !state.isProcessing) {
        final finalBarcode = state.buffer;
        
        // Minimum length for a barcode is usually 3-4 digits. 
        // We'll process if length >= 3 or if idle for a while.
        if (finalBarcode.length >= 3) {
          state = state.copyWith(isProcessing: true);
          onComplete(finalBarcode);
          state = const BarcodeScannerState();
        } else {
          // Noise or intentional typing that we missed - just clear.
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
