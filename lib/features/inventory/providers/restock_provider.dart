import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/restock_record.dart';
import '../models/bill_payment.dart'; // New
import '../../products/providers/product_provider.dart';
import '../../products/models/product_financials.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';
import 'bill_payment_provider.dart'; // New

class RestockRepository {
  final String _uid;
  final sb.SupabaseClient _supabase;
  final Ref _ref;

  RestockRepository(this._uid, this._supabase, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'restock_history');

  // ── Sync Logic ────────────────────────────────────────────────────────────

  Future<void> bootstrap({bool force = false}) async {
    // 1. Bootstrap Restock History
    final rBox = await _getBox();
    if (rBox.isEmpty || force) {
      final snap = await _supabase.from('restock_history').select().eq('user_id', _uid);
      if (force) await rBox.clear();
      for (final d in snap) {
        await rBox.put(d['id'], LocalDatabase.sanitize(d));
      }
    }

    // 2. Bootstrap Bill Payments
    final pBox = await LocalDatabase.openBox(_uid, 'bill_payments');
    if (pBox.isEmpty || force) {
      final snap = await _supabase.from('bill_payments').select().eq('user_id', _uid);
      if (force) await pBox.clear();
      for (final d in snap) {
        await pBox.put(d['id'], LocalDatabase.sanitize(d));
      }
    }
  }

  Stream<List<RestockRecord>> getRestockStream() async* {
    final box = await _getBox();
    yield _recordsFromBox(box);
    yield* box.watch().map((_) => _recordsFromBox(box));
  }

  List<RestockRecord> _recordsFromBox(Box box) {
    final list = box.values.map((d) => RestockRecord.fromMap(Map<String, dynamic>.from(d as Map))).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> saveRestock(RestockRecord record) async {
    final box = await _getBox();
    final data = record.toMap();
    data['user_id'] = _uid;
    await box.put(record.id, data);

    // 1. Sync Record
    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'restock_history',
      documentId: record.id,
      action:     SyncAction.update,
      data:       data,
    );

    // 2. Update Product Stock and Financials
    await _refreshProductState(record.productId);
  }

  Future<void> updateRestock(RestockRecord old, RestockRecord next) async {
    final box = await _getBox();
    final data = next.toMap();
    data['user_id'] = _uid;
    await box.put(next.id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'restock_history',
      documentId: next.id,
      action:     SyncAction.update,
      data:       data,
    );

    // Update product stock and financials
    await _refreshProductState(next.productId);
  }

  Future<void> deleteRestock(RestockRecord record) async {
    final box = await _getBox();
    await box.delete(record.id);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'restock_history',
      documentId: record.id,
      action:     SyncAction.delete,
      data:       {},
    );

    // Clean up related bill payments
    try {
      final payRepo = _ref.read(billPaymentRepositoryProvider);
      final payBox = await LocalDatabase.openBox(_uid, 'bill_payments');
      final payments = payBox.values
          .map((d) => BillPayment.fromMap(Map<String, dynamic>.from(d as Map)))
          .where((p) => p.billId == record.id)
          .toList();
      
      for (final p in payments) {
        await payRepo.deletePayment(p);
      }
    } catch (_) {}

    await _refreshProductState(record.productId);
  }

  /// Calculates total stock and latest financials from all restock records and updates the product.
  Future<void> _refreshProductState(String productId) async {
  }

  Future<void> adjustProductStock(String productId, double delta) async {
    final prodRepo = _ref.read(productRepositoryProvider);
    await prodRepo.updateStock(productId, delta);
  }

  Future<void> updatePayment(RestockRecord record, {required bool isSupplier, required double paidAmount, required PaymentStatus status}) async {
    final box = await _getBox();
    final updated = record.copyWith(
      supplierPaidAmount: isSupplier ? (record.supplierPaidAmount + paidAmount) : record.supplierPaidAmount,
      shippingPaidAmount: !isSupplier ? (record.shippingPaidAmount + paidAmount) : record.shippingPaidAmount,
      supplierPaymentStatus: isSupplier ? status : record.supplierPaymentStatus,
      shippingPaymentStatus: !isSupplier ? status : record.shippingPaymentStatus,
    );
    final data = updated.toMap();
    data['user_id'] = _uid;
    await box.put(record.id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'restock_history',
      documentId: record.id,
      action:     SyncAction.update,
      data:       data,
    );

    await _refreshProductState(record.productId);
  }

  Future<void> syncLatestFinancials(String productId) async {
    final box = await _getBox();
    final allRecords = _recordsFromBox(box).where((r) => r.productId == productId).toList();
    if (allRecords.isEmpty) return;

    // Latest by date
    allRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = allRecords.first;

    final prodRepo = _ref.read(productRepositoryProvider);
    final products = await prodRepo.getAllProducts();
    final product = products.firstWhere((p) => p.id == productId);

    final updated = product.copyWith(
      costPrice: latest.totalCostPerUnit,
      basePrice: latest.sellingPrice > 0 ? latest.sellingPrice : product.basePrice, // Update selling price if provided
      financials: product.financials.copyWith(
        supplierPrice: latest.supplierPrice,
        supplierShippingCost: latest.shippingCost,
        supplierName: latest.supplierName,
        supplierPaymentStatus: latest.supplierPaymentStatus,
        shippingServiceName: latest.shippingServiceName,
        shippingPaymentStatus: latest.shippingPaymentStatus,
      ),
    );
    await prodRepo.saveProduct(updated, updated.units);
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final restockRepositoryProvider = Provider<RestockRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  final supabase = ref.watch(supabaseClientProvider);
  return RestockRepository(user?.uid ?? 'unknown', supabase, ref);
});

final restockHistoryProvider = StreamProvider<List<RestockRecord>>((ref) {
  final repo = ref.watch(restockRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getRestockStream();
});

class RestockNotifier extends Notifier<void> {
  RestockRepository get _repo => ref.read(restockRepositoryProvider);

  @override
  void build() {}

  Future<void> addRestock(RestockRecord record) async {
    await _repo.adjustProductStock(record.productId, record.quantityAdded);
    await _repo.saveRestock(record);
    await _repo.syncLatestFinancials(record.productId);
  }

  Future<void> updateRestock(RestockRecord old, RestockRecord next) async {
    final delta = next.quantityAdded - old.quantityAdded;
    await _repo.adjustProductStock(next.productId, delta);
    await _repo.updateRestock(old, next);
    await _repo.syncLatestFinancials(next.productId);
  }

  Future<void> deleteRestock(RestockRecord record) async {
    await _repo.adjustProductStock(record.productId, -record.quantityAdded);
    await _repo.deleteRestock(record);
    await _repo.syncLatestFinancials(record.productId);
  }
}

final restockNotifierProvider = NotifierProvider<RestockNotifier, void>(RestockNotifier.new);
