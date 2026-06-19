import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../../auth/providers/auth_provider.dart';

final _uuid = const Uuid();

class DebtRepository {
  final String _uid;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DebtRepository(this._uid);

  DocumentReference get _userDoc => _db.collection('users').doc(_uid);
  CollectionReference get _customersCol => _userDoc.collection('customers');
  CollectionReference get _debtsCol => _userDoc.collection('debts');
  CollectionReference get _paymentsCol => _userDoc.collection('debt_payments');

  // ── Customers ─────────────────────────────────────────────────────────────

  Stream<List<Customer>> getCustomersStream() {
    return _customersCol
        .orderBy('name')
        .snapshots()
        .map((s) => s.docs.map((d) => Customer.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> saveCustomer(Customer c) async {
    await _customersCol.doc(c.id).set(c.toMap());
  }

  Future<void> deleteCustomer(String id) async {
    final doc = await _customersCol.doc(id).get();
    final data = doc.data() as Map<String, dynamic>?;
    if (data != null && (data['total_outstanding'] as num? ?? 0) > 0) {
      throw 'Tidak bisa menghapus pelanggan yang masih memiliki piutang aktif.';
    }
    await _customersCol.doc(id).delete();
  }

  // ── Debts ─────────────────────────────────────────────────────────────────

  Stream<List<Debt>> getDebtsStream({String? customerId}) {
    Query query = _debtsCol.orderBy('created_at', descending: true);
    if (customerId != null) {
      query = query.where('customer_id', isEqualTo: customerId);
    }
    return query.snapshots().map((s) => s.docs.map((d) => Debt.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> createDebt(Debt debt) async {
    final batch = _db.batch();
    batch.set(_debtsCol.doc(debt.id), debt.toMap());
    batch.update(_customersCol.doc(debt.customerId), {
      'total_outstanding': FieldValue.increment(debt.remainingBalance),
    });
    await batch.commit();
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  Stream<List<DebtPayment>> getPaymentsStream({String? customerId, String? debtId}) {
    Query query = _paymentsCol.orderBy('created_at', descending: true);
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
    
    final debtDoc = await _debtsCol.doc(debtId).get();
    if (!debtDoc.exists) throw 'Data piutang tidak ditemukan';
    
    final debt = Debt.fromMap(debtDoc.data() as Map<String, dynamic>);
    final newPaidAmount = debt.paidAmount + amount;
    final newRemaining  = debt.remainingBalance - amount;
    
    if (newRemaining < -0.01) throw 'Jumlah bayar melebihi sisa piutang';

    DebtStatus status = DebtStatus.partiallyPaid;
    if (newRemaining <= 0.01) {
      status = DebtStatus.paid;
    }

    batch.update(_debtsCol.doc(debtId), {
      'paid_amount':       newPaidAmount,
      'remaining_balance': newRemaining < 0 ? 0 : newRemaining,
      'status':            status.name,
    });

    final paymentId = _uuid.v4();
    final payment = DebtPayment(
      id:         paymentId,
      debtId:     debtId,
      customerId: customerId,
      amount:     amount,
      createdAt:  now,
      notes:      notes,
    );
    batch.set(_paymentsCol.doc(paymentId), payment.toMap());

    batch.update(_customersCol.doc(customerId), {
      'total_outstanding': FieldValue.increment(-amount),
    });

    await batch.commit();
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return DebtRepository(user?.uid ?? 'unknown');
});

final customersProvider = StreamProvider<List<Customer>>((ref) {
  final repo = ref.watch(debtRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getCustomersStream();
});

final debtsProvider = StreamProvider.family<List<Debt>, String?>((ref, customerId) {
  final repo = ref.watch(debtRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getDebtsStream(customerId: customerId);
});

final debtPaymentsProvider = StreamProvider.family<List<DebtPayment>, ({String? customerId, String? debtId})>((ref, arg) {
  final repo = ref.watch(debtRepositoryProvider);
  if (repo._uid == 'unknown') return Stream.value([]);
  return repo.getPaymentsStream(customerId: arg.customerId, debtId: arg.debtId);
});
