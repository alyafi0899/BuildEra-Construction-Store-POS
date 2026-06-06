import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Barcode Scanner State ──────────────────────────────────────────────────

class BarcodeScannerState {
  final String buffer;
  final bool isScanning;

  const BarcodeScannerState({
    this.buffer = '',
    this.isScanning = false,
  });

  BarcodeScannerState copyWith({
    String? buffer,
    bool? isScanning,
  }) =>
      BarcodeScannerState(
        buffer: buffer ?? this.buffer,
        isScanning: isScanning ?? this.isScanning,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────

class BarcodeScannerNotifier extends Notifier<BarcodeScannerState> {
  @override
  BarcodeScannerState build() => const BarcodeScannerState();

  /// Add character to buffer. Returns true if barcode is complete.
  bool onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    final logicalKey = event.logicalKey;

    // Check if terminator detected (Enter, Tab, or similar)
    if (logicalKey == LogicalKeyboardKey.enter ||
        logicalKey == LogicalKeyboardKey.tab) {
      if (state.buffer.isEmpty) return false;
      // Barcode complete - don't clear yet, let caller read it
      return true;
    }

    // Ignore special keys
    if (_isSpecialKey(logicalKey)) return false;

    // Extract character from key
    final char = _extractChar(event);
    if (char == null) return false;

    state = state.copyWith(buffer: state.buffer + char);
    return false;
  }

  void clearBuffer() {
    state = const BarcodeScannerState();
  }

  bool _isSpecialKey(LogicalKeyboardKey key) {
    return key == LogicalKeyboardKey.shift ||
        key == LogicalKeyboardKey.control ||
        key == LogicalKeyboardKey.alt ||
        key == LogicalKeyboardKey.meta ||
        key == LogicalKeyboardKey.capsLock ||
        key == LogicalKeyboardKey.numLock ||
        key == LogicalKeyboardKey.scrollLock ||
        key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete;
  }

  String? _extractChar(KeyEvent event) {
    try {
      // Try to get the character from the key event
      final character = event.character;
      if (character != null && character.isNotEmpty) {
        return character;
      }
    } catch (_) {}
    return null;
  }
}

final barcodeScannerProvider =
    NotifierProvider<BarcodeScannerNotifier, BarcodeScannerState>(
        BarcodeScannerNotifier.new);
