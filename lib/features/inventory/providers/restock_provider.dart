import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/restock_record.dart';
import '../models/bill_payment.dart';
import '../../products/providers/product_provider.dart';
import '../../products/models/product_financials.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';
import 'bill_payment_provider.dart';

class RestockRepository {
  final String _uid;
  final SupabaseClient _client;
  final Ref _ref;

  RestockRepository(this._uid, this._client, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'restock_history');

  // ── Sync Logic ────────────────────────────────────────────────────────────

  Future<void> bootstrap({bool force = false}) async {
    const int chunkSize = 50;

    Future<void> syncCollection(String boxName, String supabaseTable) async {
      final box = await LocalDatabase.openBox(_uid, boxName);
      if (box.isNotEmpty && !force) return;

      final response = await _client
          .from(supabaseTable)
          .select()
          .eq('user_id', _uid)
          .timeout(const Duration(seconds: 20));
      
      final Map<String, dynamic> allEntries = {};
      for (final item in response) {
        allEntries[item['id']] = LocalDatabase.sanitize(item);
      }

      if (force) await box.clear();

      final keys = allEntries.keys.toList();
      for (var i = 0; i < keys.length; i += chunkSize) {
        final end = (i + chunkSize < keys.length) ? i + chunkSize : keys.length;
        final Map<String, dynamic> batch = {};
        for (var j = i; j < end; j++) {
          batch[keys[j]] = allEntries[keys[j]];
        }
        await box.putAll(batch);
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    await syncCollection('restock_history', 'restock_history');
    await syncCollection('bill_payments', 'bill_payments');
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
    await box.put(record.id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'restock_history',
      documentId: record.id,
      action:     SyncAction.update,
      data:       data,
    );

    final payRepo = _ref.read(billPaymentRepositoryProvider);
    if (record.supplierPaidAmount > 0) {
      await payRepo.createInitialPayment(
        billId: record.id, 
        amount: record.supplierPaidAmount, 
        isForSupplier: true
      );
    }
    if (record.shippingPaidAmount > 0) {
      await payRepo.createInitialPayment(
        billId: record.id, 
        amount: record.shippingPaidAmount, 
        isForSupplier: false
      );
    }

    await _refreshProductState(record.productId);
  }

  Future<void> updateRestock(RestockRecord old, RestockRecord next) async {
    final box = await _getBox();
    await box.put(next.id, next.toMap());

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'restock_history',
      documentId: next.id,
      action:     SyncAction.update,
      data:       next.toMap(),
    );

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

  Future<void> _refreshProductState(String productId) async {
    // Stock logic managed via deltas in Notifier
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
    await box.put(record.id, updated.toMap());

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'restock_history',
      documentId: record.id,
      action:     SyncAction.update,
      data:       updated.toMap(),
    );

    await _refreshProductState(record.productId);
  }

  Future<void> syncLatestFinancials(String productId) async {
    final box = await _getBox();
    final allRecords = _recordsFromBox(box).where((r) => r.productId == productId).toList();
    if (allRecords.isEmpty) return;

    allRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = allRecords.first;

    final prodRepo = _ref.read(productRepositoryProvider);
    final products = await prodRepo.getAllProducts();
    final product = products.firstWhere((p) => p.id == productId);

    final updated = product.copyWith(
      costPrice: latest.totalCostPerUnit,
      basePrice: latest.sellingPrice > 0 ? latest.sellingPrice : product.basePrice,
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
  final client = ref.read(supabaseClientProvider);
  return RestockRepository(user?.uid ?? 'unknown', client, ref);
});

final restockHistoryProvider = StreamProvider<List<RestockRecord>>((ref) {
  final repo = ref.watch(restockRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getRestockStream();
});

class RestockNotifier extends Notifier<void> {
  RestockRepository get _repo => ref.read(restockRepositoryProvider);
  @override void build() {}
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
