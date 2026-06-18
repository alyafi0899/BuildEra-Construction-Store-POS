import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/barcode_scanner_provider.dart';
import '../../../products/providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/barcode_event_provider.dart';
import '../../../../shared/models/product.dart';

class BarcodeListener extends ConsumerStatefulWidget {
  final Widget child;
  final bool autoAdd;

  const BarcodeListener({
    required this.child,
    this.autoAdd = true,
    super.key,
  });

  @override
  ConsumerState<BarcodeListener> createState() => _BarcodeListenerState();
}

class _BarcodeListenerState extends ConsumerState<BarcodeListener> {
  late FocusNode _focusNode;
  String? _lastBarcode;
  DateTime? _lastScanAt;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'GlobalBarcodeListener');
    _ensureFocus();
  }

  void _ensureFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final primaryFocus = FocusManager.instance.primaryFocus;
        if (primaryFocus == null || primaryFocus.debugLabel == 'Root Focus') {
          _focusNode.requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (event) {
        final primaryFocus = FocusManager.instance.primaryFocus;
        final isTyping = primaryFocus != null && 
            (primaryFocus.context?.widget is EditableText || 
             primaryFocus.debugLabel?.contains('EditableText') == true ||
             primaryFocus.debugLabel?.contains('TextField') == true);
        
        if (isTyping) {
          ref.read(barcodeScannerProvider.notifier).clearBuffer();
          return;
        }

        ref.read(barcodeScannerProvider.notifier).onKeyEvent(
          event,
          onComplete: (barcode) {
            _handleBarcodeComplete(context, ref, barcode);
          },
        );
      },
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                final primaryFocus = FocusManager.instance.primaryFocus;
                final isTyping = primaryFocus != null && 
                    (primaryFocus.context?.widget is EditableText || 
                     primaryFocus.debugLabel?.contains('EditableText') == true);
                
                if (!isTyping) {
                  _focusNode.requestFocus();
                }
              }
            });
          }
        },
        child: widget.child,
      ),
    );
  }

  Future<void> _handleBarcodeComplete(
    BuildContext context,
    WidgetRef ref,
    String barcode,
  ) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) return;

    final now = DateTime.now();
    if (_lastBarcode == normalizedBarcode &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastBarcode = normalizedBarcode;
    _lastScanAt = now;

    ScaffoldMessenger.of(context).clearSnackBars();

    Product? matching;
    final productsAsync = ref.read(productsProvider);

    if (productsAsync is AsyncData<List<Product>>) {
      matching = _findProductInList(productsAsync.value, normalizedBarcode);
    } 

    if (matching == null) {
      try {
        matching = await ref
            .read(productRepositoryProvider)
            .getProductByBarcode(normalizedBarcode);
      } catch (e) {
        debugPrint('Barcode DB Lookup Error: $e');
      }
    }

    if (!context.mounted) return;

    // Broadcast the event globally regardless of success/failure
    ref.read(barcodeEventProvider.notifier).emit(BarcodeEvent(
      barcode: normalizedBarcode, 
      product: matching
    ));

    if (matching == null) {
      if (normalizedBarcode.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode "$normalizedBarcode" tidak terdaftar'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (widget.autoAdd) {
      ref.read(cartProvider.notifier).addProduct(matching);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text('${matching.name} masuk keranjang')),
          ]),
          duration: const Duration(milliseconds: 1000),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Product? _findProductInList(List<Product> products, String barcode) {
    for (final product in products) {
      if (product.barcode?.trim() == barcode) {
        return product;
      }
    }
    return null;
  }
}
