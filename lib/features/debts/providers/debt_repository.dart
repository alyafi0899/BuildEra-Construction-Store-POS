import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/customer.dart';
import '../models/debt.dart';
import '../models/debt_payment.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/sync/models/sync_task.dart';
import '../../../core/sync/providers/sync_provider.dart';
import '../../../core/sync/services/local_database.dart';

final _uuid = const Uuid();

class DebtRepository {
  final String _uid;
  final Ref _ref;

  DebtRepository(this._uid, this._ref);

  Future<Box> _getBox(String col) => LocalDatabase.openBox(_uid, col);

  // ── Sync Logic ────────────────────────────────────────────────────────────

  Future<void> bootstrap({bool force = false}) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(_uid);
    const int chunkSize = 50;

    Future<void> syncCollection(String colName, String firestorePath) async {
      final box = await _getBox(colName);
      if (box.isNotEmpty && !force) return;

      final snap = await userDoc.collection(firestorePath).get().timeout(const Duration(seconds: 20));
      
      final Map<String, dynamic> allEntries = {};
      for (final d in snap.docs) {
        final data = Map<String, dynamic>.from(d.data() as Map);
        allEntries[d.id] = LocalDatabase.sanitize(data);
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

    // 1. Bootstrap Customers
    await syncCollection('customers', 'customers');

    // 2. Bootstrap Debts
    await syncCollection('debts', 'debts');

    // 3. Bootstrap Payments
    await syncCollection('debt_payments', 'debt_payments');
  }

  // ── Customers ─────────────────────────────────────────────────────────────

  Stream<List<Customer>> getCustomersStream() async* {
    final box = await _getBox('customers');
    yield _customersFromBox(box);
    yield* box.watch().map((_) => _customersFromBox(box));
  }

  List<Customer> _customersFromBox(Box box) {
    final list = box.values.map((d) => Customer.fromMap(Map<String, dynamic>.from(d as Map))).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> saveCustomer(Customer c) async {
    final box = await _getBox('customers');
    final data = c.toMap();
    await box.put(c.id, data);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'customers',
      documentId: c.id,
      action:     SyncAction.update,
      data:       data,
    );
  }

  Future<void> deleteCustomer(String id) async {
    final box = await _getBox('customers');
    final data = box.get(id);
    if (data != null && (data['total_outstanding'] as num? ?? 0) > 0) {
      throw 'Tidak bisa menghapus pelanggan yang masih memiliki piutang aktif.';
    }
    await box.delete(id);

    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'customers',
      documentId: id,
      action:     SyncAction.delete,
      data:       {},
    );
  }

  // ── Debts ─────────────────────────────────────────────────────────────────

  Stream<List<Debt>> getDebtsStream({String? customerId}) async* {
    final box = await _getBox('debts');
    yield _debtsFromBox(box, customerId);
    yield* box.watch().map((_) => _debtsFromBox(box, customerId));
  }

  List<Debt> _debtsFromBox(Box box, String? customerId) {
    var list = box.values.map((d) => Debt.fromMap(Map<String, dynamic>.from(d as Map))).toList();
    if (customerId != null) {
      list = list.where((d) => d.customerId == customerId).toList();
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<Debt>> getDebts({String? customerId}) async {
    final box = await _getBox('debts');
    return _debtsFromBox(box, customerId);
  }

  Future<void> createDebt(Debt debt) async {
    final debtBox = await _getBox('debts');
    final custBox = await _getBox('customers');

    final now = DateTime.now();
    final d = debt.updatedAt == debt.createdAt ? debt.copyWith(updatedAt: now) : debt;

    // 1. Update Debts Local
    await debtBox.put(d.id, d.toMap());

    // 2. Queue Debt Sync
    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'debts',
      documentId: d.id,
      action:     SyncAction.create,
      data:       d.toMap(),
    );

    // 3. Update Customer Local & Queue Sync
    final custData = custBox.get(debt.customerId);
    if (custData != null) {
      final m = Map<String, dynamic>.from(custData as Map);
      m['total_outstanding'] = (m['total_outstanding'] as num? ?? 0) + debt.remainingBalance;
      await custBox.put(debt.customerId, m);

      await _ref.read(syncProvider.notifier).addToQueue(
        collection: 'customers',
        documentId: debt.customerId,
        action:     SyncAction.increment,
        data:       {'total_outstanding': debt.remainingBalance, 'updated_at': now.toIso8601String()},
      );
    }
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  Stream<List<DebtPayment>> getPaymentsStream({String? customerId, String? debtId}) async* {
    final box = await _getBox('debt_payments');
    yield _paymentsFromBox(box, customerId, debtId);
    yield* box.watch().map((_) => _paymentsFromBox(box, customerId, debtId));
  }

  List<DebtPayment> _paymentsFromBox(Box box, String? customerId, String? debtId) {
    var list = box.values.map((d) => DebtPayment.fromMap(Map<String, dynamic>.from(d as Map))).toList();
    if (customerId != null) list = list.where((p) => p.customerId == customerId).toList();
    if (debtId != null)     list = list.where((p) => p.debtId == debtId).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<List<DebtPayment>> getPayments({String? customerId, String? debtId}) async {
    final box = await _getBox('debt_payments');
    return _paymentsFromBox(box, customerId, debtId);
  }

  Future<void> recordPayment({
    required String debtId,
    required String customerId,
    required double amount,
    String? notes,
  }) async {
    final debtBox = await _getBox('debts');
    final custBox = await _getBox('customers');
    final payBox  = await _getBox('debt_payments');

    final now = DateTime.now();

    // 1. Update Debt Local
    final dData = debtBox.get(debtId);
    if (dData == null) throw 'Data piutang tidak ditemukan';
    final debt = Debt.fromMap(Map<String, dynamic>.from(dData as Map));
    
    final newRemaining = debt.remainingBalance - amount;
    final status = newRemaining <= 0.01 ? DebtStatus.paid : DebtStatus.partiallyPaid;

    final updatedDebt = debt.copyWith(
      paidAmount: debt.paidAmount + amount,
      remainingBalance: newRemaining < 0 ? 0 : newRemaining,
      status: status,
      updatedAt: now,
    );
    await debtBox.put(debtId, updatedDebt.toMap());

    // 2. Create Payment Local
    final payId = _uuid.v4();
    final payment = DebtPayment(
      id: payId, debtId: debtId, customerId: customerId, 
      amount: amount, createdAt: now, notes: notes,
    );
    await payBox.put(payId, payment.toMap());

    // 3. Update Customer Local & Queue Sync
    final cData = custBox.get(customerId);
    if (cData != null) {
      final m = Map<String, dynamic>.from(cData as Map);
      m['total_outstanding'] = (m['total_outstanding'] as num? ?? 0) - amount;
      await custBox.put(customerId, m);

      await _ref.read(syncProvider.notifier).addToQueue(
        collection: 'customers', documentId: customerId, action: SyncAction.increment,
        data: {'total_outstanding': -amount, 'updated_at': now.toIso8601String()},
      );
    }

    // 4. Queue other Syncs
    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'debts', documentId: debtId, action: SyncAction.update,
      data: {
        'paid_amount': updatedDebt.paidAmount, 
        'remaining_balance': updatedDebt.remainingBalance, 
        'status': updatedDebt.status.name,
        'updated_at': updatedDebt.updatedAt.toIso8601String(),
      },
    );
    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'debt_payments', documentId: payId, action: SyncAction.create,
      data: payment.toMap(),
    );
  }

  Future<void> deleteDebt(String id) async {
    final debtBox = await _getBox('debts');
    final custBox = await _getBox('customers');
    final payBox  = await _getBox('debt_payments');

    final dData = debtBox.get(id);
    if (dData == null) return;
    final debt = Debt.fromMap(Map<String, dynamic>.from(dData as Map));

    // 1. Update Customer Balance Local
    final cData = custBox.get(debt.customerId);
    if (cData != null) {
      final m = Map<String, dynamic>.from(cData as Map);
      m['total_outstanding'] = (m['total_outstanding'] as num? ?? 0) - debt.remainingBalance;
      await custBox.put(debt.customerId, m);
      
      // Sync Customer Update
      await _ref.read(syncProvider.notifier).addToQueue(
        collection: 'customers',
        documentId: debt.customerId,
        action: SyncAction.increment,
        data: {'total_outstanding': -debt.remainingBalance, 'updated_at': DateTime.now().toIso8601String()},
      );
    }

    // 2. Delete all related payments locally and sync
    final payments = payBox.values
        .map((e) => DebtPayment.fromMap(Map<String, dynamic>.from(e as Map)))
        .where((p) => p.debtId == id)
        .toList();

    for (final p in payments) {
      await payBox.delete(p.id);
      await _ref.read(syncProvider.notifier).addToQueue(
        collection: 'debt_payments',
        documentId: p.id,
        action: SyncAction.delete,
        data: {},
      );
    }

    // 3. Delete Debt Local and Sync
    await debtBox.delete(id);
    await _ref.read(syncProvider.notifier).addToQueue(
      collection: 'debts',
      documentId: id,
      action: SyncAction.delete,
      data: {},
    );
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final user = ref.watch(authStateProvider).value;
  return DebtRepository(user?.uid ?? 'unknown', ref);
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
