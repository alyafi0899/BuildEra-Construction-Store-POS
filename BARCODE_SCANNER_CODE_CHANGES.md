# Barcode Scanner - Exact Code Changes

## File 1: cashier_page.dart

### Change 1.1: Added Import
**Location:** Line 11 (after other imports)

```dart
import '../widgets/barcode_listener.dart';
```

---

### Change 1.2: Wrapped Body with BarcodeListener
**Location:** Line 28-29 (in `build()` method)

**Before:**
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppTheme.bg,
    body: Row(children: [
      // ── Left: Product Search & Grid ──────────────────────────────────
      Expanded(
```

**After:**
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: AppTheme.bg,
    body: BarcodeListener(
      child: Row(children: [
        // ── Left: Product Search & Grid ──────────────────────────────────
        Expanded(
```

**And closing bracket:**

**Before:**
```dart
        ]),
      ),
    ],
  );
}
```

**After:**
```dart
        ]),
      ),
    ],
  )),
    ),
  );
}
```

---

## File 2: cart_provider.dart

### Change 2.1: Added Method
**Location:** Line 98-100 (after `clear()` method, before `_defaultUnit()`)

**Before:**
```dart
  void clear() => state = const CartState();

  ProductUnit _defaultUnit(Product p) => ProductUnit(
```

**After:**
```dart
  void clear() => state = const CartState();

  void addProductByBarcode(Product product) {
    addProduct(product);
  }

  ProductUnit _defaultUnit(Product p) => ProductUnit(
```

---

## File 3: barcode_scanner_provider.dart (NEW)

**Location:** `lib/features/cashier/providers/barcode_scanner_provider.dart`

**Full File Content (73 lines):**

```dart
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
```

---

## File 4: barcode_listener.dart (NEW)

**Location:** `lib/features/cashier/presentation/widgets/barcode_listener.dart`

**Full File Content (105 lines):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/barcode_scanner_provider.dart';
import '../../../products/providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../../../shared/models/product.dart';

class BarcodeListener extends ConsumerStatefulWidget {
  final Widget child;

  const BarcodeListener({required this.child, super.key});

  @override
  ConsumerState<BarcodeListener> createState() => _BarcodeListenerState();
}

class _BarcodeListenerState extends ConsumerState<BarcodeListener> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Ensure focus so keyboard events are captured
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(barcodeScannerProvider);

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        final notifier = ref.read(barcodeScannerProvider.notifier);
        final isComplete = notifier.onKeyEvent(event);

        if (isComplete) {
          _handleBarcodeComplete(context, ref, scanner.buffer);
          notifier.clearBuffer();
        }
      },
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            _focusNode.requestFocus();
          }
        },
        child: widget.child,
      ),
    );
  }

  void _handleBarcodeComplete(
    BuildContext context,
    WidgetRef ref,
    String barcode,
  ) {
    final products = ref.read(productsProvider).asData?.value ?? [];
    final matching = products.firstWhere(
      (p) => p.barcode?.trim() == barcode.trim(),
      orElse: () => Product(
        id: '',
        name: '',
        category: '',
        basePrice: 0,
        baseUnit: '',
        stock: 0,
        createdAt: DateTime(1900),
        updatedAt: DateTime(1900),
      ),
    );

    if (matching.id.isEmpty) {
      // Product not found
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Produk tidak ditemukan'),
          duration: Duration(milliseconds: 1500),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Product found, add to cart
    ref.read(cartProvider.notifier).addProduct(matching);

    // Show success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${matching.name} ditambahkan ke keranjang'),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }
}
```

---

## Summary of Changes

| File | Type | Lines Changed | What |
|------|------|----------------|------|
| `cashier_page.dart` | Existing | +1 import, +2 wrapper lines | Added BarcodeListener |
| `cart_provider.dart` | Existing | +3 lines | Added addProductByBarcode() |
| `barcode_scanner_provider.dart` | New | 73 lines | State management for barcode |
| `barcode_listener.dart` | New | 105 lines | Global keyboard listener widget |

**Total:** 4 files, ~181 lines of new/modified code

---

## Diff Summary

```diff
+ File: lib/features/cashier/providers/barcode_scanner_provider.dart
  New file, 73 lines

+ File: lib/features/cashier/presentation/widgets/barcode_listener.dart
  New file, 105 lines

~ File: lib/features/cashier/presentation/pages/cashier_page.dart
  + 1 import (barcode_listener.dart)
  ~ Wrapped body: Row → BarcodeListener(child: Row)

~ File: lib/features/cashier/providers/cart_provider.dart
  + 2 lines (addProductByBarcode method)
```

---

## Verification Commands

Verify all files compile:

```bash
# Check individual files
flutter analyze lib/features/cashier/providers/barcode_scanner_provider.dart
flutter analyze lib/features/cashier/presentation/widgets/barcode_listener.dart
flutter analyze lib/features/cashier/presentation/pages/cashier_page.dart
flutter analyze lib/features/cashier/providers/cart_provider.dart

# Full project analysis
flutter analyze

# Expected result: No errors, only pre-existing info/warnings
```

Format code (optional):

```bash
dart format lib/features/cashier/providers/barcode_scanner_provider.dart
dart format lib/features/cashier/presentation/widgets/barcode_listener.dart
```

---

**Ready to test! 🚀**
