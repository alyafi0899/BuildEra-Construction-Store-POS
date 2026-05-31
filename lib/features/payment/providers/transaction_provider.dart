import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore hide Transaction;
import '../../../shared/models/transaction.dart';
import '../../cashier/providers/cart_provider.dart';
import '../../products/providers/product_provider.dart';

final _uuid = Uuid();

// ── Repository ─────────────────────────────────────────────────────────────

class TransactionRepository {
  final _db = firestore.FirebaseFirestore.instance;

  Future<List<Transaction>> getAllTransactions() async {
    final snapshot = await _db.collection('transactions').orderBy('created_at', descending: true).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final itemsData = data['items'] as List? ?? [];
      final items = itemsData.map((i) => TransactionItem.fromMap(i as Map<String, dynamic>)).toList();
      return Transaction.fromMap(data, items: items);
    }).toList();
  }

  Future<String> saveTransaction({
    required CartState cart,
    required String    paymentMethod,
    required double    amountPaid,
    String?            notes,
  }) async {
    final id      = _uuid.v4();
    final invoice = _invoice();
    final change  = amountPaid - cart.total;

    final t = Transaction(
      id:            id,
      invoiceNumber: invoice,
      subtotal:      cart.subtotal,
      discount:      cart.discount,
      taxRate:       cart.taxEnabled ? cart.taxRate : 0,
      taxAmount:     cart.taxAmount,
      total:         cart.total,
      paymentMethod: paymentMethod,
      amountPaid:    amountPaid,
      changeAmount:  change < 0 ? 0 : change,
      notes:         notes,
      createdAt:     DateTime.now(),
    );

    final data = t.toMap();
    data['items'] = cart.items.map((item) {
      return TransactionItem(
        id:             _uuid.v4(),
        transactionId:  id,
        productId:      item.product.id,
        productName:    item.product.name,
        unitName:       item.selectedUnit.unitName,
        conversionRate: item.selectedUnit.conversionRate,
        quantity:       item.quantity,
        unitPrice:      item.selectedUnit.sellPrice,
        subtotal:       item.subtotal,
      ).toMap();
    }).toList();

    await _db.collection('transactions').doc(id).set(data);
    return id;
  }

  String _invoice() {
    final now = DateTime.now();
    final seq = now.millisecondsSinceEpoch % 10000;
    return 'INV-${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '-${seq.toString().padLeft(4, '0')}';
  }
}

// ── Analytics models ───────────────────────────────────────────────────────

class TopProduct {
  final String name;
  final double revenue;
  final double qty;
  const TopProduct(this.name, this.revenue, this.qty);
}

class SalesSummary {
  final double              totalRevenue;
  final int                 totalTransactions;
  final double              avgOrderValue;
  final Map<String, double> revenueByDay;
  final Map<String, double> revenueByPayment;
  final List<TopProduct>    topProducts;

  const SalesSummary({
    required this.totalRevenue,
    required this.totalTransactions,
    required this.avgOrderValue,
    required this.revenueByDay,
    required this.revenueByPayment,
    required this.topProducts,
  });
}

SalesSummary buildSummary(List<Transaction> txs) {
  final total = txs.fold<double>(0, (s, t) => s + t.total);
  final count = txs.length;

  final byDay = <String, double>{};
  final byPay = <String, double>{};
  final rev   = <String, double>{};
  final qty   = <String, double>{};

  for (final t in txs) {
    final day = '${t.createdAt.year}-'
        '${t.createdAt.month.toString().padLeft(2, '0')}-'
        '${t.createdAt.day.toString().padLeft(2, '0')}';
    byDay[day] = (byDay[day] ?? 0) + t.total;
    byPay[t.paymentMethod] = (byPay[t.paymentMethod] ?? 0) + t.total;
    for (final i in t.items) {
      rev[i.productName] = (rev[i.productName] ?? 0) + i.subtotal;
      qty[i.productName] = (qty[i.productName] ?? 0) + i.quantity;
    }
  }

  final top = rev.entries
      .map((e) => TopProduct(e.key, e.value, qty[e.key] ?? 0))
      .toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));

  return SalesSummary(
    totalRevenue:      total,
    totalTransactions: count,
    avgOrderValue:     count > 0 ? total / count : 0,
    revenueByDay:      byDay,
    revenueByPayment:  byPay,
    topProducts:       top.take(10).toList(),
  );
}

// ── Providers ──────────────────────────────────────────────────────────────

final transactionRepositoryProvider = Provider((_) => TransactionRepository());

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  TransactionRepository get _repo => ref.read(transactionRepositoryProvider);

  @override
  Future<List<Transaction>> build() => _repo.getAllTransactions();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.getAllTransactions);
  }

  Future<String> checkout({
    required String paymentMethod,
    required double amountPaid,
    String?         notes,
  }) async {
    final cart     = ref.read(cartProvider);
    final prodRepo = ref.read(productRepositoryProvider);

    for (final item in cart.items) {
      final baseQty = item.quantity * item.selectedUnit.conversionRate;
      await prodRepo.updateStock(item.product.id, -baseQty);
    }

    final id = await _repo.saveTransaction(
      cart:          cart,
      paymentMethod: paymentMethod,
      amountPaid:    amountPaid,
      notes:         notes,
    );

    ref.read(cartProvider.notifier).clear();
    // Wait for the state to be updated before returning
    await ref.read(productsProvider.notifier).refresh();
    await refresh();
    return id;
  }
}

final salesSummaryProvider = FutureProvider<SalesSummary>((ref) async {
  final txs = await ref.watch(transactionsProvider.future);
  return buildSummary(txs);
});
