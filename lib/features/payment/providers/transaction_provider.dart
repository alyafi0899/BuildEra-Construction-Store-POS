import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../shared/models/transaction.dart';
import '../../cashier/providers/cart_provider.dart';
import '../../products/providers/product_provider.dart';
import '../../settings/providers/settings_provider.dart';
import '../../debts/providers/debt_repository.dart';
import '../../debts/models/debt.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';

final _uuid = Uuid();

// ── Repository ─────────────────────────────────────────────────────────────

class TransactionRepository {
  final String _uid;
  final Ref _ref;

  TransactionRepository(this._uid, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'transactions');

  Future<List<Transaction>> getAllTransactions() async {
    final box = await _getBox();
    final list = box.values.map((data) {
      final m = Map<String, dynamic>.from(data as Map);
      final itemsData = m['items'] as List? ?? [];
      final items = itemsData.map((i) => TransactionItem.fromMap(Map<String, dynamic>.from(i as Map))).toList();
      return Transaction.fromMap(m, items: items);
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<Transaction> saveTransaction({
    required CartState cart,
    required String    paymentMethod,
    required double    amountPaid,
    String?            cashierName,
    String?            notes,
  }) async {
    final id      = _uuid.v4();
    final invoice = _invoice();
    final change  = amountPaid - cart.total;

    final t = Transaction(
      id:                 id,
      invoiceNumber:      invoice,
      customerId:         cart.customerId,
      customerName:       cart.customerName,
      cashierName:        cashierName,
      subtotal:           cart.grossSubtotal,
      itemDiscountTotal:  cart.itemDiscountTotal,
      transDiscountValue: cart.transDiscountValue,
      transDiscountType:  cart.transDiscountType,
      transDiscountAmount:cart.transDiscountAmount,
      taxRate:            cart.taxEnabled ? cart.taxRate : 0,
      taxAmount:          cart.taxAmount,
      total:              cart.total,
      paymentMethod:      paymentMethod,
      amountPaid:         amountPaid,
      changeAmount:       change < 0 ? 0 : change,
      notes:              notes,
      createdAt:          DateTime.now(),
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
        costPrice:      item.costPrice,
        originalPrice:  item.originalPrice,
        soldPrice:      item.soldPrice,
        discountValue:  item.discountValue,
        discountType:   item.discountType,
        subtotal:       item.subtotal,
      ).toMap();
    }).toList();

    // 1. Write Local
    final box = await _getBox();
    await box.put(id, data);

    // 2. Queue Sync
    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'transactions',
      documentId: id,
      action:     SyncAction.create,
      data:       data,
    );

    return t;
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

// ── Analytics models & logic ... (remain unchanged) ───────────────────────

class TopProduct {
  final String name;
  final double revenue;
  final double profit;
  final double qty;
  const TopProduct(this.name, this.revenue, this.profit, this.qty);
}

class DailySummary {
  final String date;
  final double revenue;
  final double grossProfit;
  final double netProfit;
  final int transactionCount;
  final List<Transaction> transactions;

  const DailySummary({
    required this.date,
    required this.revenue,
    required this.grossProfit,
    required this.netProfit,
    required this.transactionCount,
    this.transactions = const [],
  });
}

class SalesSummary {
  final double              totalRevenue;
  final double              totalGrossProfit;
  final double              totalNetProfit;
  final int                 totalTransactions;
  final double              avgOrderValue;
  final Map<String, double> revenueByDay;
  final Map<String, double> netProfitByDay;
  final Map<String, double> revenueByPayment;
  final List<TopProduct>    topProducts;
  final List<DailySummary>  dailyDetails;

  const SalesSummary({
    required this.totalRevenue,
    required this.totalGrossProfit,
    required this.totalNetProfit,
    required this.totalTransactions,
    required this.avgOrderValue,
    required this.revenueByDay,
    required this.netProfitByDay,
    required this.revenueByPayment,
    required this.topProducts,
    required this.dailyDetails,
  });
}

SalesSummary buildSummary(List<Transaction> txs) {
  double totalRevenue = 0;
  double totalGrossProfit = 0;
  double totalNetProfit  = 0;
  final count = txs.length;

  final byDayRevenue = <String, double>{};
  final byDayGrossProfit = <String, double>{};
  final byDayNetProfit  = <String, double>{};
  final byDayTxs     = <String, List<Transaction>>{};
  
  final byPay = <String, double>{};
  final rev   = <String, double>{};
  final prf   = <String, double>{};
  final qty   = <String, double>{};

  for (final t in txs) {
    totalRevenue += t.total;
    
    double itemCosts = t.items.fold(0, (s, i) => s + (i.costPrice * i.quantity));
    double tGrossProfit = t.items.fold(0, (s, i) => s + ((i.originalPrice - i.costPrice) * i.quantity));
    totalGrossProfit += tGrossProfit;

    double tNetProfit = (t.total - t.taxAmount) - itemCosts;
    totalNetProfit += tNetProfit;

    final day = '${t.createdAt.year}-'
        '${t.createdAt.month.toString().padLeft(2, '0')}-'
        '${t.createdAt.day.toString().padLeft(2, '0')}';
    
    byDayRevenue[day] = (byDayRevenue[day] ?? 0) + t.total;
    byDayGrossProfit[day] = (byDayGrossProfit[day] ?? 0) + tGrossProfit;
    byDayNetProfit[day]  = (byDayNetProfit[day] ?? 0) + tNetProfit;
    byDayTxs[day]     = [...(byDayTxs[day] ?? []), t];

    byPay[t.paymentMethod] = (byPay[t.paymentMethod] ?? 0) + t.total;
    
    for (final i in t.items) {
      rev[i.productName] = (rev[i.productName] ?? 0) + i.subtotal;
      prf[i.productName] = (prf[i.productName] ?? 0) + (i.subtotal - (i.costPrice * i.quantity));
      qty[i.productName] = (qty[i.productName] ?? 0) + i.quantity;
    }
  }

  final top = rev.entries
      .map((e) => TopProduct(e.key, e.value, prf[e.key] ?? 0, qty[e.key] ?? 0))
      .toList()
    ..sort((a, b) => b.revenue.compareTo(a.revenue));

  final dailyDetails = byDayRevenue.entries.map((e) {
    return DailySummary(
      date:             e.key,
      revenue:          e.value,
      grossProfit:      byDayGrossProfit[e.key] ?? 0,
      netProfit:        byDayNetProfit[e.key] ?? 0,
      transactionCount: byDayTxs[e.key]?.length ?? 0,
      transactions:      byDayTxs[e.key] ?? [],
    );
  }).toList()..sort((a, b) => b.date.compareTo(a.date));

  return SalesSummary(
    totalRevenue:      totalRevenue,
    totalGrossProfit:  totalGrossProfit,
    totalNetProfit:    totalNetProfit,
    totalTransactions: count,
    avgOrderValue:     count > 0 ? totalRevenue / count : 0,
    revenueByDay:      byDayRevenue,
    netProfitByDay:    byDayNetProfit,
    revenueByPayment:  byPay,
    topProducts:       top.take(10).toList(),
    dailyDetails:      dailyDetails,
  );
}

// ── Providers ──────────────────────────────────────────────────────────────

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return TransactionRepository(user?.uid ?? 'unknown', ref);
});

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
  TransactionsNotifier.new,
);

class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  TransactionRepository get _repo => ref.read(transactionRepositoryProvider);

  @override
  Future<List<Transaction>> build() async {
    if (_repo._uid == 'unknown') return [];
    return _repo.getAllTransactions();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_repo.getAllTransactions);
  }

  Future<String> checkout({
    required String paymentMethod,
    required double amountPaid,
    DateTime?       dueDate,
    String?         notes,
  }) async {
    final cart     = ref.read(cartProvider);
    final settings = ref.read(settingsProvider);
    final prodRepo = ref.read(productRepositoryProvider);
    final debtRepo = ref.read(debtRepositoryProvider);

    for (final item in cart.items) {
      final baseQty = item.quantity * item.selectedUnit.conversionRate;
      await prodRepo.updateStock(item.product.id, -baseQty);
    }

    final tx = await _repo.saveTransaction(
      cart:          cart,
      paymentMethod: paymentMethod,
      amountPaid:    amountPaid,
      cashierName:   settings.ownerName.isEmpty ? 'Admin' : settings.ownerName,
      notes:         notes,
    );

    if (paymentMethod == AppConstants.paymentPiutang && cart.customerId != null) {
      final remaining = cart.total - amountPaid;
      if (remaining > 0) {
        final debtId = _uuid.v4();
        final debt = Debt(
          id:               debtId,
          transactionId:    tx.id,
          customerId:       cart.customerId!,
          customerName:     cart.customerName ?? 'Pelanggan',
          invoiceNumber:    tx.invoiceNumber,
          totalAmount:      cart.total,
          paidAmount:       amountPaid,
          remainingBalance: remaining,
          dueDate:          dueDate ?? DateTime.now().add(const Duration(days: 30)),
          createdAt:        DateTime.now(),
          status:           amountPaid > 0 ? DebtStatus.partiallyPaid : DebtStatus.unpaid,
          notes:            notes,
        );
        await debtRepo.createDebt(debt);
      }
    }

    ref.read(cartProvider.notifier).clear();
    await refresh();
    return tx.id;
  }
}

final salesSummaryProvider = FutureProvider<SalesSummary>((ref) async {
  final txs = await ref.watch(transactionsProvider.future);
  return buildSummary(txs);
});
