import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/barcode_scanner_provider.dart';
import '../../../products/providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../../../shared/models/product.dart';

class BarcodeListener extends ConsumerStatefulWidget {
  final Widget child;
  final Function(Product)? onProductFound;

  const BarcodeListener({
    required this.child,
    this.onProductFound,
    super.key,
  });

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
    // We don't watch scanner here to avoid unnecessary rebuilds during typing
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: (event) {
        final notifier = ref.read(barcodeScannerProvider.notifier);
        final isComplete = notifier.onKeyEvent(event);

        if (isComplete) {
          // IMPORTANT: Read the latest buffer from state, NOT from a watched variable
          final buffer = ref.read(barcodeScannerProvider).buffer;
          _handleBarcodeComplete(context, ref, buffer);
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
    // Clear any existing snackbars to avoid queuing and "slow" feeling
    ScaffoldMessenger.of(context).clearSnackBars();

    final products = ref.read(productsProvider).asData?.value ?? [];
    final matching = products.firstWhere(
      (p) => p.barcode?.trim() == barcode.trim(),
      orElse: () => Product(
        id: '',
        name: '',
        category: '',
        costPrice: 0,
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
          content: Text('Barcode tidak terdaftar'),
          duration: Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 1. ADD TO CART FIRST (Instant Update)
    ref.read(cartProvider.notifier).addProduct(matching);

    // 2. Clear Search in UI
    if (widget.onProductFound != null) {
      widget.onProductFound!(matching);
    }

    // 3. Very brief success feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${matching.name} ditambahkan'),
        duration: const Duration(milliseconds: 400),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }
}
