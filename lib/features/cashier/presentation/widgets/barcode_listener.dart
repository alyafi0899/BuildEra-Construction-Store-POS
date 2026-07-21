import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/barcode_scanner_provider.dart';
import '../../../products/providers/product_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/barcode_event_provider.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/common_widgets.dart';

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
        // Process Barcode ALWAYS, but pass whether we are typing to the handler
        final primaryFocus = FocusManager.instance.primaryFocus;
        bool isUserInField = false;
        if (primaryFocus != null) {
          final widget = primaryFocus.context?.widget;
          final label = primaryFocus.debugLabel ?? '';
          isUserInField = widget is EditableText || 
                         label.contains('EditableText') || 
                         label.contains('TextField') ||
                         label.contains('TextFormField');
        }

        ref.read(barcodeScannerProvider.notifier).onKeyEvent(
          event,
          onComplete: (barcode) {
            _handleBarcodeComplete(context, ref, barcode, isUserInField);
          },
        );
      },
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus) {
            // When we lose focus, we check if the new focus is on a text field.
            // If it IS a text field, we stay there indefinitely (no refocused to scanner).
            // We only request focus back if the user clicks on "nothing" or an inert area.
            
            // Short delay to let the focus system settle and identify the new target
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                final primaryFocus = FocusManager.instance.primaryFocus;
                
                bool isUserInField = false;
                if (primaryFocus != null) {
                  final widget = primaryFocus.context?.widget;
                  final label = primaryFocus.debugLabel ?? '';
                  isUserInField = widget is EditableText || 
                                 label.contains('EditableText') || 
                                 label.contains('TextField') ||
                                 label.contains('TextFormField');
                }
                
                // If the user is NOT in a field, we eventually want the scanner back.
                // We use a longer delay (5s) for "safety", but the important part is 
                // that if isUserInField is TRUE, we NEVER request focus back.
                if (!isUserInField && primaryFocus != _focusNode) {
                  Future.delayed(const Duration(seconds: 5), () {
                    if (mounted) {
                      final currentFocus = FocusManager.instance.primaryFocus;
                      if (currentFocus == null || currentFocus.debugLabel == 'Root Focus') {
                        _focusNode.requestFocus();
                      }
                    }
                  });
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
    bool isUserInField,
  ) async {
    final normalizedBarcode = barcode.trim();
    if (normalizedBarcode.isEmpty) return;

    // Reset buffer tracking for next scan
    final now = DateTime.now();
    if (_lastBarcode == normalizedBarcode &&
        _lastScanAt != null &&
        now.difference(_lastScanAt!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastBarcode = normalizedBarcode;
    _lastScanAt = now;

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

    // Emit event for UI synchronization
    ref.read(barcodeEventProvider.notifier).emit(BarcodeEvent(
      barcode: normalizedBarcode, 
      product: matching,
      wasFocused: isUserInField,
    ));

    if (matching == null) {
      // ONLY show error if the scan was clearly NOT manual typing
      // Manual typing doesn't have the 'isValidSpeed' flag set in the provider's logic
      // But we double check here: if user is in field, we are SILENT on errors.
      if (!isUserInField && normalizedBarcode.length >= 3) {
        ScaffoldMessenger.of(context).clearSnackBars();
        showError(context, 'Barcode "$normalizedBarcode" tidak terdaftar');
      }
      return;
    }

    // Auto-add logic
    if (widget.autoAdd && !isUserInField) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ref.read(cartProvider.notifier).addProduct(matching);
      showSuccess(context, '${matching.name} masuk keranjang');
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
