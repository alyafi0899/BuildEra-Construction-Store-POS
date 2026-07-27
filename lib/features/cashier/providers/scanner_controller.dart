import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/product.dart';
import '../../products/providers/product_provider.dart';
import 'cart_provider.dart';

class ScannerState {
  final bool isScanning;
  final String? lastScannedBarcode;
  final DateTime? lastScanTime;
  final bool hasError;
  final String? errorMessage;

  ScannerState({
    this.isScanning = true,
    this.lastScannedBarcode,
    this.lastScanTime,
    this.hasError = false,
    this.errorMessage,
  });

  ScannerState copyWith({
    bool? isScanning,
    String? lastScannedBarcode,
    DateTime? lastScanTime,
    bool? hasError,
    String? errorMessage,
  }) {
    return ScannerState(
      isScanning: isScanning ?? this.isScanning,
      lastScannedBarcode: lastScannedBarcode ?? this.lastScannedBarcode,
      lastScanTime: lastScanTime ?? this.lastScanTime,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

enum ScanResult { added, ignored, notFound }

class ScannerController extends Notifier<ScannerState> {
  final Duration _cooldown = const Duration(milliseconds: 1500);

  @override
  ScannerState build() => ScannerState();

  /// Handles a scanned barcode. 
  ScanResult onBarcodeScanned(String barcode) {
    final now = DateTime.now();
    
    // Duplicate prevention / Cooldown logic
    if (state.lastScannedBarcode == barcode &&
        state.lastScanTime != null &&
        now.difference(state.lastScanTime!) < _cooldown) {
      return ScanResult.ignored; 
    }

    state = state.copyWith(
      lastScannedBarcode: barcode,
      lastScanTime: now,
    );

    // Optimized lookup using the map provider
    final productMap = ref.read(barcodeProductMapProvider);
    final product = productMap[barcode];

    if (product != null) {
      ref.read(cartProvider.notifier).addProduct(product);
      return ScanResult.added;
    } 
    
    return ScanResult.notFound;
  }

  void setScanning(bool value) {
    state = state.copyWith(isScanning: value);
  }
  
  void reset() {
    state = ScannerState();
  }
}

final scannerControllerProvider =
    NotifierProvider<ScannerController, ScannerState>(ScannerController.new);

/// A provider that indexes products by barcode for O(1) lookup.
final barcodeProductMapProvider = Provider<Map<String, Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  return productsAsync.when(
    data: (products) {
      final map = <String, Product>{};
      for (final p in products) {
        if (p.barcode != null && p.barcode!.trim().isNotEmpty) {
          map[p.barcode!.trim()] = p;
        }
      }
      return map;
    },
    loading: () => {},
    error: (_, __) => {},
  );
});
