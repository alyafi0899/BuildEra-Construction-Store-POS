import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/bill_payment.dart';
import '../models/restock_record.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';
import '../../products/providers/product_provider.dart';
import '../../products/models/product_financials.dart';

class BillPaymentRepository {
  final String _uid;
  final Ref _ref;
  final supabase.SupabaseClient _client = supabase.Supabase.instance.client;

  BillPaymentRepository(this._uid, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'bill_payments');

  // ── Sync Logic ────────────────────────────────────────────────────────────

  Future<void> bootstrap({bool force = false}) async {
    final pBox = await _getBox();
    if (pBox.isEmpty || force) {
      final response = await _client.from('bill_payments').select().eq('user_id', _uid).timeout(const Duration(seconds: 15));
      if (force) await pBox.clear();
      for (final d in (response as List)) {
        final data = Map<String, dynamic>.from(d as Map);
        await pBox.put(data['id'], LocalDatabase.sanitize(data));
      }
    }
  }

  Stream<List<BillPayment>> getPaymentsStream() async* {
    final box = await _getBox();
    yield _paymentsFromBox(box);
    yield* box.watch().map((_) => _paymentsFromBox(box));
  }

  List<BillPayment> _paymentsFromBox(Box box) {
    final list = box.values.map((d) => BillPayment.fromMap(Map<String, dynamic>.from(d as Map))).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> savePayment(BillPayment payment) async {
    final box = await _getBox();
    await box.put(payment.id, payment.toMap());

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'bill_payments',
      documentId: payment.id,
      action:     SyncAction.update,
      data:       payment.toMap(),
    );
    
    await _recalculateBillStatus(payment.billId, payment.isInitialBill, targetIsSupplier: payment.isForSupplier);
  }

  Future<void> createInitialPayment({
    required String billId,
    required double amount,
    required bool isForSupplier,
  }) async {
    // SECURITY: Get current entity names before creating payment
    final repo = _ref.read(productRepositoryProvider);
    final products = await repo.getAllProducts();
    final p = products.where((item) => item.id == billId).firstOrNull;
    
    String? entityName;
    if (p != null) {
      entityName = isForSupplier ? p.financials.supplierName : p.financials.shippingServiceName;
    } else {
      // Check restock history if product not found (could be a restock bill ID)
      final restockBox = await LocalDatabase.openBox(_uid, 'restock_history');
      final rData = restockBox.get(billId);
      if (rData != null) {
        final r = RestockRecord.fromMap(Map<String, dynamic>.from(rData as Map));
        entityName = isForSupplier ? r.supplierName : r.shippingServiceName;
      }
    }

    // ONLY create payment record if entity name is NOT null/empty
    if (entityName == null || entityName.trim().isEmpty) return;

    final box = await _getBox();
    final allPayments = _paymentsFromBox(box).where((p) => p.billId == billId && p.isForSupplier == isForSupplier).toList();
    
    // Only create if NO payments exist yet for this bill/entity (prevent duplicates on edit)
    if (allPayments.isEmpty) {
      final payment = BillPayment(
        id: Uuid().v4(),
        billId: billId,
        amount: amount,
        notes: 'Pembayaran Awal / DP',
        createdAt: DateTime.now(),
        isInitialBill: true,
        isForSupplier: isForSupplier,
      );
      await savePayment(payment);
    }
  }

  Future<void> deletePayment(BillPayment payment) async {
    final box = await _getBox();
    await box.delete(payment.id);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'bill_payments',
      documentId: payment.id,
      action:     SyncAction.delete,
      data:       {},
    );

    await _recalculateBillStatus(payment.billId, payment.isInitialBill, targetIsSupplier: payment.isForSupplier);
  }

  Future<void> _recalculateBillStatus(String billId, bool isInitial, {bool? targetIsSupplier}) async {
    final box = await _getBox();
    final allPayments = _paymentsFromBox(box).where((p) => p.billId == billId).toList();
    
    final totalSupplierPaid = allPayments.where((p) => p.isForSupplier).fold<double>(0, (s, p) => s + p.amount);
    final totalShippingPaid = allPayments.where((p) => !p.isForSupplier).fold<double>(0, (s, p) => s + p.amount);

    const epsilon = 0.5;

    if (isInitial) {
      final repo = _ref.read(productRepositoryProvider);
      final products = await repo.getAllProducts();
      final p = products.where((item) => item.id == billId).firstOrNull;
      if (p != null) {
        final f = p.financials;

        // --- 1. Supplier Status Calculation ---
        PaymentStatus sStatus = f.supplierPaymentStatus;
        if (targetIsSupplier == null || targetIsSupplier == true) {
          final sDue = f.supplierPrice;
          if (sDue <= 0) {
            sStatus = PaymentStatus.notApplicable;
          } else if (totalSupplierPaid >= (sDue - epsilon)) {
            sStatus = PaymentStatus.paid;
          } else if (totalSupplierPaid > epsilon) {
            sStatus = PaymentStatus.partial;
          } else {
            sStatus = f.supplierPaymentStatus == PaymentStatus.notApplicable 
                ? PaymentStatus.notApplicable 
                : PaymentStatus.unpaid;
          }
        }
        
        // --- 2. Shipping Status Calculation ---
        PaymentStatus shStatus = f.shippingPaymentStatus;
        if (targetIsSupplier == null || targetIsSupplier == false) {
          final shDue = f.supplierShippingCost;
          if (shDue <= 0) {
            shStatus = PaymentStatus.notApplicable;
          } else if (totalShippingPaid >= (shDue - epsilon)) {
            shStatus = PaymentStatus.paid;
          } else if (totalShippingPaid > epsilon) {
            shStatus = PaymentStatus.partial;
          } else {
            shStatus = f.shippingPaymentStatus == PaymentStatus.notApplicable 
                ? PaymentStatus.notApplicable 
                : PaymentStatus.unpaid;
          }
        }

        final updated = p.copyWith(
          financials: f.copyWith(
            supplierPaidAmount: totalSupplierPaid,
            shippingPaidAmount: totalShippingPaid,
            supplierPaymentStatus: sStatus,
            shippingPaymentStatus: shStatus,
          ),
        );
        
        final boxProd = await LocalDatabase.openBox(_uid, 'products');
        await boxProd.put(updated.id, updated.toMap());
        await _ref.read(syncProvider.notifier).addToQueue(collection: 'products', documentId: updated.id, action: SyncAction.update, data: updated.toMap());
      }
    } else {
      final boxRestock = await LocalDatabase.openBox(_uid, 'restock_history');
      final rData = boxRestock.get(billId);
      if (rData != null) {
        final r = RestockRecord.fromMap(Map<String, dynamic>.from(rData as Map));
        
        // --- 1. Supplier Status Calculation ---
        PaymentStatus sStatus = r.supplierPaymentStatus;
        if (targetIsSupplier == null || targetIsSupplier == true) {
          final sDue = r.supplierPrice;
          if (sDue <= 0) {
            sStatus = PaymentStatus.notApplicable;
          } else if (totalSupplierPaid >= (sDue - epsilon)) {
            sStatus = PaymentStatus.paid;
          } else if (totalSupplierPaid > epsilon) {
            sStatus = PaymentStatus.partial;
          } else {
            sStatus = r.supplierPaymentStatus == PaymentStatus.notApplicable 
                ? PaymentStatus.notApplicable 
                : PaymentStatus.unpaid;
          }
        }
        
        // --- 2. Shipping Status Calculation ---
        PaymentStatus shStatus = r.shippingPaymentStatus;
        if (targetIsSupplier == null || targetIsSupplier == false) {
          final shDue = r.shippingCost;
          if (shDue <= 0) {
            shStatus = PaymentStatus.notApplicable;
          } else if (totalShippingPaid >= (shDue - epsilon)) {
            shStatus = PaymentStatus.paid;
          } else if (totalShippingPaid > epsilon) {
            shStatus = PaymentStatus.partial;
          } else {
            shStatus = r.shippingPaymentStatus == PaymentStatus.notApplicable 
                ? PaymentStatus.notApplicable 
                : PaymentStatus.unpaid;
          }
        }
        
        final updated = r.copyWith(
          supplierPaidAmount: totalSupplierPaid,
          shippingPaidAmount: totalShippingPaid,
          supplierPaymentStatus: sStatus,
          shippingPaymentStatus: shStatus,
        );
        
        await boxRestock.put(updated.id, updated.toMap());
        await _ref.read(syncProvider.notifier).addToQueue(collection: 'restock_history', documentId: updated.id, action: SyncAction.update, data: updated.toMap());
      }
    }
  }
}

final billPaymentRepositoryProvider = Provider<BillPaymentRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return BillPaymentRepository(user?.uid ?? 'unknown', ref);
});

final billPaymentsProvider = StreamProvider<List<BillPayment>>((ref) {
  final repo = ref.watch(billPaymentRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getPaymentsStream();
});
