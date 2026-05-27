// lib/shared/widgets/barcode_listener.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a widget subtree and listens for rapid keyboard input
/// characteristic of a USB barcode scanner (complete string in < 100ms).
class BarcodeListener extends StatefulWidget {
  final Widget child;
  final ValueChanged<String> onBarcodeScanned;
  final Duration threshold;

  const BarcodeListener({
    super.key,
    required this.child,
    required this.onBarcodeScanned,
    this.threshold = const Duration(milliseconds: 100),
  });

  @override
  State<BarcodeListener> createState() => _BarcodeListenerState();
}

class _BarcodeListenerState extends State<BarcodeListener> {
  final StringBuffer _buffer = StringBuffer();
  DateTime? _lastKeyTime;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final now = DateTime.now();
    final key = event.logicalKey;

    // Enter key signals end of barcode
    if (key == LogicalKeyboardKey.enter) {
      final barcode = _buffer.toString().trim();
      _buffer.clear();
      if (barcode.isNotEmpty) {
        widget.onBarcodeScanned(barcode);
      }
      return;
    }

    // Reset buffer if too much time has passed (human typing)
    if (_lastKeyTime != null &&
        now.difference(_lastKeyTime!) > widget.threshold) {
      _buffer.clear();
    }

    _lastKeyTime = now;

    // Accumulate printable characters
    final char = event.character;
    if (char != null && char.isNotEmpty) {
      _buffer.write(char);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: false,
      onKeyEvent: _handleKey,
      child: widget.child,
    );
  }
}
