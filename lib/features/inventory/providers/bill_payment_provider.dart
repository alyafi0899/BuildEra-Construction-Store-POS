import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
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

  BillPaymentRepository(this._uid, this._ref);

  Future<Box> _getBox() => LocalDatabase.openBox(_uid, 'bill_payments');

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
    
    await _recalculateBillStatus(payment.billId, payment.isInitialBill);
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

    await _recalculateBillStatus(payment.billId, payment.isInitialBill);
  }

  Future<void> _recalculateBillStatus(String billId, bool isInitial) async {
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
        final sDue = f.supplierPrice;
        PaymentStatus sStatus;
        if (sDue <= 0) {
          sStatus = PaymentStatus.notApplicable;
        } else if (totalSupplierPaid >= (sDue - epsilon)) {
          sStatus = PaymentStatus.paid;
        } else if (totalSupplierPaid > epsilon) {
          sStatus = PaymentStatus.partial;
        } else {
          // If no payments yet, only set to unpaid if it wasn't already dismissed (notApplicable)
          sStatus = f.supplierPaymentStatus == PaymentStatus.notApplicable 
              ? PaymentStatus.notApplicable 
              : PaymentStatus.unpaid;
        }
        
        // --- 2. Shipping Status Calculation ---
        final shDue = f.supplierShippingCost;
        PaymentStatus shStatus;
        if (shDue <= 0) {
          shStatus = PaymentStatus.notApplicable;
        } else if (totalShippingPaid >= (shDue - epsilon)) {
          shStatus = PaymentStatus.paid;
        } else if (totalShippingPaid > epsilon) {
          shStatus = PaymentStatus.partial;
        } else {
          // If no payments yet, only set to unpaid if it wasn't already dismissed (notApplicable)
          shStatus = f.shippingPaymentStatus == PaymentStatus.notApplicable 
              ? PaymentStatus.notApplicable 
              : PaymentStatus.unpaid;
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
        final sDue = r.supplierPrice;
        PaymentStatus sStatus;
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
        
        // --- 2. Shipping Status Calculation ---
        final shDue = r.shippingCost;
        PaymentStatus shStatus;
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
