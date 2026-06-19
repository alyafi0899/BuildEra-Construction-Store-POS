import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';

final _uuid = const Uuid();

class DebtRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Customers ─────────────────────────────────────────────────────────────

  Stream<List<Customer>> getCustomersStream() {
    return _db.collection('customers')
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => Customer.fromMap(d.data())).toList());
  }

  Future<void> saveCustomer(Customer c) async {
    await _db.collection('customers').doc(c.id).set(c.toMap());
  }

  Future<void> deleteCustomer(String id) async {
    // Check if customer has outstanding debt
    final doc = await _db.collection('customers').doc(id).get();
    final data = doc.data();
    if (data != null && (data['total_outstanding'] as num? ?? 0) > 0) {
      throw 'Tidak bisa menghapus pelanggan yang masih memiliki piutang aktif.';
    }
    await _db.collection('customers').doc(id).delete();
  }

  // ── Debts ─────────────────────────────────────────────────────────────────

  Stream<List<Debt>> getDebtsStream({String? customerId}) {
    Query query = _db.collection('debts').orderBy('created_at', descending: true);
    if (customerId != null) {
      query = query.where('customer_id', isEqualTo: customerId);
    }
    return query.snapshots().map((s) => s.docs.map((d) => Debt.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> createDebt(Debt debt) async {
    final batch = _db.batch();
    
    // 1. Create debt doc
    batch.set(_db.collection('debts').doc(debt.id), debt.toMap());
    
    // 2. Update customer outstanding balance
    batch.update(_db.collection('customers').doc(debt.customerId), {
      'total_outstanding': FieldValue.increment(debt.remainingBalance),
    });
    
    await batch.commit();
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  Stream<List<DebtPayment>> getPaymentsStream({String? customerId, String? debtId}) {
    Query query = _db.collection('debt_payments').orderBy('created_at', descending: true);
    if (customerId != null) {
      query = query.where('customer_id', isEqualTo: customerId);
    }
    if (debtId != null) {
      query = query.where('debt_id', isEqualTo: debtId);
    }
    return query.snapshots().map((s) => s.docs.map((d) => DebtPayment.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> recordPayment({
    required String debtId,
    required String customerId,
    required double amount,
    String? notes,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();
    
    // 1. Get current debt
    final debtDoc = await _db.collection('debts').doc(debtId).get();
    if (!debtDoc.exists) throw 'Data piutang tidak ditemukan';
    
    final debt = Debt.fromMap(debtDoc.data() as Map<String, dynamic>);
    final newPaidAmount = debt.paidAmount + amount;
    final newRemaining  = debt.remainingBalance - amount;
    
    if (newRemaining < -0.01) throw 'Jumlah bayar melebihi sisa piutang';

    DebtStatus status = DebtStatus.partiallyPaid;
    if (newRemaining <= 0.01) {
      status = DebtStatus.paid;
    }

    // 2. Update debt
    batch.update(_db.collection('debts').doc(debtId), {
      'paid_amount':       newPaidAmount,
      'remaining_balance': newRemaining < 0 ? 0 : newRemaining,
      'status':            status.name,
    });

    // 3. Create payment record
    final paymentId = _uuid.v4();
    final payment = DebtPayment(
      id:         paymentId,
      debtId:     debtId,
      customerId: customerId,
      amount:     amount,
      createdAt:  now,
      notes:      notes,
    );
    batch.set(_db.collection('debt_payments').doc(paymentId), payment.toMap());

    // 4. Update customer balance
    batch.update(_db.collection('customers').doc(customerId), {
      'total_outstanding': FieldValue.increment(-amount),
    });

    await batch.commit();
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final debtRepositoryProvider = Provider((ref) => DebtRepository());

final customersProvider = StreamProvider<List<Customer>>((ref) {
  return ref.watch(debtRepositoryProvider).getCustomersStream();
});

final debtsProvider = StreamProvider.family<List<Debt>, String?>((ref, customerId) {
  return ref.watch(debtRepositoryProvider).getDebtsStream(customerId: customerId);
});

final debtPaymentsProvider = StreamProvider.family<List<DebtPayment>, ({String? customerId, String? debtId})>((ref, arg) {
  return ref.watch(debtRepositoryProvider).getPaymentsStream(customerId: arg.customerId, debtId: arg.debtId);
});
