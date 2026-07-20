import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/models/product.dart';
import '../../products/models/product_financials.dart';
import '../../inventory/models/restock_record.dart';
import '../../inventory/providers/restock_provider.dart';
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

enum AnalyticsPeriod { daily, weekly, monthly, yearly, all }

class AnalyticsPeriodNotifier extends Notifier<AnalyticsPeriod> {
  @override
  AnalyticsPeriod build() => AnalyticsPeriod.all;

  void setPeriod(AnalyticsPeriod period) {
    state = period;
  }
}

final analyticsPeriodProvider = NotifierProvider<AnalyticsPeriodNotifier, AnalyticsPeriod>(AnalyticsPeriodNotifier.new);

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

  Future<Transaction?> getTransactionById(String id) async {
    final box = await _getBox();
    final data = box.get(id);
    if (data == null) return null;
    final m = Map<String, dynamic>.from(data as Map);
    final itemsData = m['items'] as List? ?? [];
    final items = itemsData.map((i) => TransactionItem.fromMap(Map<String, dynamic>.from(i as Map))).toList();
    return Transaction.fromMap(m, items: items);
  }

  Future<Transaction> saveTransaction({
    required CartState cart,
    required String    paymentMethod,
    required double    amountPaid,
    double             shippingFee = 0,
    String?            cashierName,
    String?            notes,
  }) async {
    final id      = _uuid.v4();
    final invoice = _invoice();
    final finalTotal = cart.total + shippingFee;
    final change  = amountPaid - finalTotal;

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
      taxRate:            cart.taxEnabled ? cart.taxRate : 0.11,
      taxAmount:          cart.taxAmount,
      shippingFee:        shippingFee,
      total:              finalTotal,
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

    final box = await _getBox();
    await box.put(id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'transactions',
      documentId: id,
      action:     SyncAction.create,
      data:       data,
    );

    return t;
  }

  Future<void> deleteTransaction(String id) async {
    final box = await _getBox();
    await box.delete(id);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'transactions',
      documentId: id,
      action:     SyncAction.delete,
      data:       {},
    );
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

// ── Models ─────────────────────────────────────────────────────────────

class UnpaidBillDetail {
  final String entityName;
  final double remainingAmount;
  final int count;
  const UnpaidBillDetail({required this.entityName, required this.remainingAmount, required this.count});
}

class TopProduct {
  final String name;
  final String unit;
  final double revenue;
  final double profit;
  final double qty;
  final double costPrice;
  final double soldPrice;

  const TopProduct({
    required this.name,
    required this.unit,
    required this.revenue,
    required this.profit,
    required this.qty,
    required this.costPrice,
    required this.soldPrice,
  });
}

class DailySummary {
  final String date;
  final double revenue;
  final double grossProfit;
  final double netProfit;
  final int transactionCount;
  final List<Transaction> transactions;

  double get cashTotal => transactions.where((t) => t.paymentMethod == 'Tunai').fold(0.0, (s, t) => s + t.total);
  double get qrisTotal => transactions.where((t) => t.paymentMethod == 'QRIS').fold(0.0, (s, t) => s + t.total);
  double get debtTotal => transactions.where((t) => t.paymentMethod == AppConstants.paymentPiutang).fold(0.0, (s, t) => s + t.total);

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
  final Map<int, double>    netProfitByHour; // Added for hourly breakdown
  final Map<String, double> revenueByPayment;
  final List<TopProduct>    topProducts;
  final List<DailySummary>  dailyDetails;
  final AnalyticsPeriod     period; // Keep track of period

  final double todayRevenue;
  final double todayNetProfit;
  final double monthlyRevenue;
  final double monthlyNetProfit;
  final double potentialInventoryProfit;
  final double maxInventoryProfit;
  final int unpaidSupplierProducts;
  final int unpaidShippingProducts;
  
  final List<UnpaidBillDetail> unpaidSupplierDetails;
  final List<UnpaidBillDetail> unpaidShippingDetails;

  const SalesSummary({
    required this.totalRevenue,
    required this.totalGrossProfit,
    required this.totalNetProfit,
    required this.totalTransactions,
    required this.avgOrderValue,
    required this.revenueByDay,
    required this.netProfitByDay,
    required this.netProfitByHour,
    required this.revenueByPayment,
    required this.topProducts,
    required this.dailyDetails,
    required this.todayRevenue,
    required this.todayNetProfit,
    required this.monthlyRevenue,
    required this.monthlyNetProfit,
    required this.potentialInventoryProfit,
    required this.maxInventoryProfit,
    required this.unpaidSupplierProducts,
    required this.unpaidShippingProducts,
    required this.unpaidSupplierDetails,
    required this.unpaidShippingDetails,
    required this.period,
  });
}

// ── Build Logic ─────────────────────────────────────────────────────────────

SalesSummary buildSummary(List<Transaction> txs, List<Product> products, List<RestockRecord> restocks, {AnalyticsPeriod period = AnalyticsPeriod.all}) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
  final startOfMonth = DateTime(now.year, now.month, 1);
  final startOfYear = DateTime(now.year, 1, 1);

  List<Transaction> filteredTxs = txs;
  if (period == AnalyticsPeriod.daily) {
    filteredTxs = txs.where((t) => t.createdAt.isAfter(startOfToday) || t.createdAt.isAtSameMomentAs(startOfToday)).toList();
  } else if (period == AnalyticsPeriod.weekly) {
    filteredTxs = txs.where((t) => t.createdAt.isAfter(startOfWeek) || t.createdAt.isAtSameMomentAs(startOfWeek)).toList();
  } else if (period == AnalyticsPeriod.monthly) {
    filteredTxs = txs.where((t) => t.createdAt.isAfter(startOfMonth) || t.createdAt.isAtSameMomentAs(startOfMonth)).toList();
  } else if (period == AnalyticsPeriod.yearly) {
    filteredTxs = txs.where((t) => t.createdAt.isAfter(startOfYear) || t.createdAt.isAtSameMomentAs(startOfYear)).toList();
  }

  double totalRevenue = 0;
  double totalGrossProfit = 0;
  double totalNetProfit  = 0;
  final count = filteredTxs.length;

  final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final thisMonth = now.month;
  final thisYear = now.year;

  double todayRev = 0;
  double todayNet = 0;
  double monthlyRev = 0;
  double monthlyNet = 0;

  final byDayRevenue = <String, double>{};
  final byDayGrossProfit = <String, double>{};
  final byDayNetProfit  = <String, double>{};
  final byDayTxs     = <String, List<Transaction>>{};
  
  final byPay = <String, double>{};
  
  final productAggregators = <String, _ProductAggregator>{};

  // Hourly profit for daily view
  final byHourNetProfit = period == AnalyticsPeriod.daily ? _getHourlyNetProfit(filteredTxs) : <int, double>{};

  for (final t in filteredTxs) {
    totalRevenue += t.total;
    
    double itemCosts = t.items.fold(0, (s, i) => s + (i.costPrice * i.quantity));
    double tGrossProfit = t.items.fold(0, (s, i) => s + ((i.originalPrice - i.costPrice) * i.quantity));
    totalGrossProfit += tGrossProfit;

    double tNetProfit = (t.total - t.taxAmount) - itemCosts;
    totalNetProfit += tNetProfit;

    final day = '${t.createdAt.year}-'
        '${t.createdAt.month.toString().padLeft(2, '0')}-'
        '${t.createdAt.day.toString().padLeft(2, '0')}';
    
    if (day == todayStr) {
      todayRev += t.total;
      todayNet += tNetProfit;
    }

    if (t.createdAt.month == thisMonth && t.createdAt.year == thisYear) {
      monthlyRev += t.total;
      monthlyNet += tNetProfit;
    }

    byDayRevenue[day] = (byDayRevenue[day] ?? 0) + t.total;
    byDayGrossProfit[day] = (byDayGrossProfit[day] ?? 0) + tGrossProfit;
    byDayNetProfit[day]  = (byDayNetProfit[day] ?? 0) + tNetProfit;
    byDayTxs[day]     = [...(byDayTxs[day] ?? []), t];

    byPay[t.paymentMethod] = (byPay[t.paymentMethod] ?? 0) + t.total;
    
    for (final i in t.items) {
      final key = '${i.productName}|${i.unitName}';
      final agg = productAggregators.putIfAbsent(key, () => _ProductAggregator(i.productName, i.unitName));
      agg.revenue += i.subtotal;
      agg.profit += (i.subtotal - (i.costPrice * i.quantity));
      agg.qty += i.quantity;
      agg.costPrice = i.costPrice;
      agg.soldPrice = i.soldPrice;
    }
  }

  double potentialProfit = 0;
  double maxPossibleProfit = 0;
  for (final p in products) {
    final unitProfit = p.basePrice - p.costPrice;
    if (p.stock > 0) potentialProfit += p.stock * unitProfit;
    final soldQty = productAggregators.values.where((a) => a.name == p.name).fold<double>(0, (s, a) => s + a.qty);
    maxPossibleProfit += (p.stock + soldQty) * unitProfit;
  }

  final supplierMap = <String, ({double amount, double paid, int count})>{};
  final shippingMap = <String, ({double amount, double paid, int count})>{};
  
  void addBill(String? name, double total, double paid, PaymentStatus status, bool isShip) {
    if (status == PaymentStatus.notApplicable) return;
    final n = (name ?? (isShip ? 'Ekspedisi Umum' : 'Supplier Umum')).trim();
    if (n.isEmpty) return;

    if (isShip) {
      final prev = shippingMap[n] ?? (amount: 0.0, paid: 0.0, count: 0);
      shippingMap[n] = (amount: prev.amount + total, paid: prev.paid + paid, count: prev.count + 1);
    } else {
      final prev = supplierMap[n] ?? (amount: 0.0, paid: 0.0, count: 0);
      supplierMap[n] = (amount: prev.amount + total, paid: prev.paid + paid, count: prev.count + 1);
    }
  }

  for (final r in restocks) {
    addBill(r.supplierName, r.supplierPrice, r.supplierPaidAmount, r.supplierPaymentStatus, false);
    addBill(r.shippingServiceName, r.shippingCost, r.shippingPaidAmount, r.shippingPaymentStatus, true);
  }

  final productIdsWithRestocks = restocks.map((r) => r.productId).toSet();
  for (final p in products) {
    if (!productIdsWithRestocks.contains(p.id)) {
      addBill(p.financials.supplierName, p.financials.supplierPrice, p.financials.supplierPaidAmount, p.financials.supplierPaymentStatus, false);
      addBill(p.financials.shippingServiceName, p.financials.supplierShippingCost, p.financials.shippingPaidAmount, p.financials.shippingPaymentStatus, true);
    }
  }

  const epsilon = 0.5;
  final unpaidSupList = supplierMap.entries.where((e) => e.value.amount - e.value.paid > epsilon).map((e) => UnpaidBillDetail(entityName: e.key, remainingAmount: e.value.amount - e.value.paid, count: e.value.count)).toList();
  final unpaidShipList = shippingMap.entries.where((e) => e.value.amount - e.value.paid > epsilon).map((e) => UnpaidBillDetail(entityName: e.key, remainingAmount: e.value.amount - e.value.paid, count: e.value.count)).toList();

  final top = productAggregators.values.map((a) => TopProduct(name: a.name, unit: a.unit, revenue: a.revenue, profit: a.profit, qty: a.qty, costPrice: a.costPrice, soldPrice: a.soldPrice)).toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

  final dailyDetails = byDayRevenue.entries.map((e) {
    return DailySummary(date: e.key, revenue: e.value, grossProfit: byDayGrossProfit[e.key] ?? 0, netProfit: byDayNetProfit[e.key] ?? 0, transactionCount: byDayTxs[e.key]?.length ?? 0, transactions: byDayTxs[e.key] ?? []);
  }).toList()..sort((a, b) => b.date.compareTo(a.date));

  return SalesSummary(
    totalRevenue: totalRevenue, totalGrossProfit: totalGrossProfit, totalNetProfit: totalNetProfit, totalTransactions: count, avgOrderValue: count > 0 ? totalRevenue / count : 0, 
    revenueByDay: byDayRevenue, netProfitByDay: byDayNetProfit, 
    netProfitByHour: byHourNetProfit, // Pass hourly data
    revenueByPayment: byPay, topProducts: top.toList(), dailyDetails: dailyDetails, todayRevenue: todayRev, todayNetProfit: todayNet, monthlyRevenue: monthlyRev, monthlyNetProfit: monthlyNet, potentialInventoryProfit: potentialProfit, maxInventoryProfit: maxPossibleProfit, unpaidSupplierProducts: unpaidSupList.length, unpaidShippingProducts: unpaidShipList.length, unpaidSupplierDetails: unpaidSupList, unpaidShippingDetails: unpaidShipList,
    period: period, // Pass period
  );
}

Map<int, double> _getHourlyNetProfit(List<Transaction> txs) {
  final map = <int, double>{};
  for (final t in txs) {
    final hour = t.createdAt.hour;
    double itemCosts = t.items.fold(0, (s, i) => s + (i.costPrice * i.quantity));
    double tNetProfit = (t.total - t.taxAmount) - itemCosts;
    map[hour] = (map[hour] ?? 0) + tNetProfit;
  }
  return map;
}

class _ProductAggregator {
  final String name;
  final String unit;
  double revenue = 0;
  double profit = 0;
  double qty = 0;
  double costPrice = 0;
  double soldPrice = 0;
  _ProductAggregator(this.name, this.unit);
}

// ── Providers ──────────────────────────────────────────────────────────────

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return TransactionRepository(user?.uid ?? 'unknown', ref);
});

final transactionsProvider = StreamProvider<List<Transaction>>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  
  // Create a stream that emits the current transactions and then watches for changes
  final controller = StreamController<List<Transaction>>();
  
  void update() async {
    final list = await repo.getAllTransactions();
    if (!controller.isClosed) controller.add(list);
  }

  // Initial fetch
  update();

  // Watch the Hive box for changes
  final boxFuture = repo._getBox();
  boxFuture.then((box) {
    if (!ref.mounted) return;
    final subscription = box.watch().listen((_) => update());
    ref.onDispose(() => subscription.cancel());
  });

  ref.onDispose(() => controller.close());
  return controller.stream;
});

class TransactionsNotifier extends Notifier<void> {
  TransactionRepository get _repo => ref.read(transactionRepositoryProvider);

  @override
  void build() {}

  Future<void> refresh() async {
    // With StreamProvider, refresh is usually automatic, but we can invalidate if needed
    ref.invalidate(transactionsProvider);
  }

  Future<String> checkout({
    required String paymentMethod,
    required double amountPaid,
    double shippingFee = 0,
    DateTime? dueDate,
    String? notes,
  }) async {
    final cart = ref.read(cartProvider);
    final settings = ref.read(settingsProvider);
    final prodRepo = ref.read(productRepositoryProvider);
    final debtRepo = ref.read(debtRepositoryProvider);

    // 1. Update Product Stock
    for (final item in cart.items) {
      final baseQty = item.quantity * item.selectedUnit.conversionRate;
      await prodRepo.updateStock(item.product.id, -baseQty);
    }

    // 2. Save Transaction
    final tx = await _repo.saveTransaction(
      cart: cart,
      paymentMethod: paymentMethod,
      amountPaid: amountPaid,
      shippingFee: shippingFee,
      cashierName: settings.ownerName.isEmpty ? 'Admin' : settings.ownerName,
      notes: notes,
    );

    // 3. Handle Piutang
    if (paymentMethod == AppConstants.paymentPiutang && cart.customerId != null) {
      final remaining = tx.total - amountPaid;
      if (remaining > 0) {
        final debtId = _uuid.v4();
        final debt = Debt(
          id: debtId,
          transactionId: tx.id,
          customerId: cart.customerId!,
          customerName: cart.customerName ?? 'Pelanggan',
          invoiceNumber: tx.invoiceNumber,
          totalAmount: tx.total,
          paidAmount: amountPaid,
          remainingBalance: remaining,
          dueDate: dueDate ?? DateTime.now().add(const Duration(days: 30)),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          status: amountPaid > 0 ? DebtStatus.partiallyPaid : DebtStatus.unpaid,
          notes: notes,
        );
        await debtRepo.createDebt(debt);
      }
    }

    // 4. Clear Cart and Notify Related Providers
    ref.read(cartProvider.notifier).clear();
    
    // Explicitly invalidate to ensure UI sync
    ref.invalidate(productsProvider);
    ref.invalidate(customersProvider);
    ref.invalidate(salesSummaryProvider);
    
    return tx.id;
  }

  Future<void> deleteTransaction(String id) async {
    try {
      final prodRepo = ref.read(productRepositoryProvider);
      final debtRepo = ref.read(debtRepositoryProvider);
      
      // 1. Get transaction to restore stock
      final tx = await _repo.getTransactionById(id);
      if (tx != null) {
        for (final item in tx.items) {
          final baseQty = item.quantity * item.conversionRate;
          await prodRepo.updateStock(item.productId, baseQty);
        }
      }

      // 2. Delete linked debt if exists
      final debts = await ref.read(debtsProvider(null).future);
      final debt = debts.firstWhereOrNull((d) => d.transactionId == id);
      if (debt != null) {
        await debtRepo.deleteDebt(debt.id);
      }

      // 3. Delete transaction record
      await _repo.deleteTransaction(id);

      // 4. Invalidate related providers to ensure sync
      ref.invalidate(productsProvider);
      ref.invalidate(customersProvider);
      ref.invalidate(salesSummaryProvider);
    } catch (e) {
      debugPrint('Error deleting transaction: $e');
      rethrow;
    }
  }
}

// Re-expose the notifier
final transactionsActionProvider = NotifierProvider<TransactionsNotifier, void>(TransactionsNotifier.new);

final transactionByIdProvider = FutureProvider.family<Transaction?, String>((ref, id) async {
  return ref.watch(transactionRepositoryProvider).getTransactionById(id);
});

final salesSummaryProvider = FutureProvider<SalesSummary>((ref) async {
  final txs = await ref.watch(transactionsProvider.future);
  final products = await ref.watch(productsProvider.future);
  final restocks = await ref.watch(restockHistoryProvider.future);
  final period = ref.watch(analyticsPeriodProvider);
  return buildSummary(txs, products, restocks, period: period);
});
