import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/product.dart';

class BarcodeEvent {
  final String barcode;
  final Product? product;
  final DateTime timestamp;

  BarcodeEvent({required this.barcode, this.product}) : timestamp = DateTime.now();
}

/// Use Notifier instead of StateProvider for better compatibility on Windows
final barcodeEventProvider = NotifierProvider<BarcodeEventNotifier, BarcodeEvent?>(BarcodeEventNotifier.new);

class BarcodeEventNotifier extends Notifier<BarcodeEvent?> {
  @override
  BarcodeEvent? build() => null;

  void emit(BarcodeEvent event) {
    state = event;
  }
}
