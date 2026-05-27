// lib/features/payment/presentation/providers/transaction_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/hive/hive_models.dart';
import '../../../../data/hive/hive_service.dart';
import '../../../cashier/domain/entities/cart_entity.dart';
import '../../../cashier/presentation/providers/cart_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';

class TransactionResult {
  final bool success;
  final String? transactionCode;
  final String? error;
  const TransactionResult({required this.success, this.transactionCode, this.error});
}

class TransactionListNotifier extends Notifier<List<HiveTransaction>> {
  @override
  List<HiveTransaction> build() => HiveService.getAllTransactions();

  void _reload() => state = HiveService.getAllTransactions();

  Future<TransactionResult> processPayment({
    required CartState cart,
    required String paymentMethod,
    required double paidAmount,
    String cashierName = 'Kasir',
  }) async {
    try {
      if (cart.isEmpty) return const TransactionResult(success: false, error: 'Keranjang kosong');

      // Validate stock
      final products = ref.read(allProductsProvider);
      for (final item in cart.items) {
        final product = products.firstWhere(
          (p) => p.id == item.productId,
          orElse: () => throw Exception('Produk ${item.productName} tidak ditemukan'),
        );
        if (product.stockQuantity < item.baseUnitQuantity) {
          return TransactionResult(
            success: false,
            error: 'Stok ${item.productName} tidak cukup '
                '(sisa: ${product.stockQuantity} ${product.baseUnit})',
          );
        }
      }

      final code = 'TRX-${DateTime.now().millisecondsSinceEpoch}';
      final change = paidAmount - cart.total;

      final tx = HiveTransaction(
        id: 0,
        transactionCode: code,
        transactionDate: DateTime.now(),
        subtotal: cart.subtotal,
        discountAmount: cart.discountAmount,
        taxAmount: cart.taxAmount,
        totalAmount: cart.total,
        paidAmount: paidAmount,
        changeAmount: change > 0 ? change : 0,
        paymentMethod: paymentMethod,
        notes: cart.notes.isEmpty ? null : cart.notes,
        status: 'completed',
        cashierName: cashierName,
        items: cart.items.map((item) => HiveTransactionItem(
          id: 0,
          transactionId: 0,
          productId: item.productId,
          productName: item.productName,
          unitName: item.unitName,
          quantity: item.quantity,
          pricePerUnit: item.pricePerUnit,
          subtotal: item.subtotal,
          conversionRatio: item.conversionRatio,
        )).toList(),
      );

      final saved = await HiveService.insertTransaction(tx);

      // Deduct stock
      for (final item in cart.items) {
        await ref.read(productNotifierProvider.notifier).deductStock(
          item.productId,
          item.baseUnitQuantity,
        );
      }

      _reload();
      ref.read(cartProvider.notifier).clearCart();

      return TransactionResult(success: true, transactionCode: saved.transactionCode);
    } catch (e) {
      return TransactionResult(success: false, error: e.toString());
    }
  }
}

final transactionListProvider =
    NotifierProvider<TransactionListNotifier, List<HiveTransaction>>(
  TransactionListNotifier.new,
);

final todaySalesProvider = Provider<double>((ref) {
  final txs = ref.watch(transactionListProvider);
  final today = DateTime.now();
  return txs
      .where((t) =>
          t.transactionDate.year == today.year &&
          t.transactionDate.month == today.month &&
          t.transactionDate.day == today.day &&
          t.status == 'completed')
      .fold(0.0, (sum, t) => sum + t.totalAmount);
});

final todayTransactionCountProvider = Provider<int>((ref) {
  final txs = ref.watch(transactionListProvider);
  final today = DateTime.now();
  return txs
      .where((t) =>
          t.transactionDate.year == today.year &&
          t.transactionDate.month == today.month &&
          t.transactionDate.day == today.day)
      .length;
});
