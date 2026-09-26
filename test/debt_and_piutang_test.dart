import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/features/debts/models/customer.dart';
import 'package:buildera/features/debts/models/debt.dart';

void main() {
  group('Debt and Piutang Management Tests', () {
    final now = DateTime.now();
    final dueDate = now.add(const Duration(days: 30));

    test('Customer model serialization and outstanding balance', () {
      final customer = Customer(
        id: 'cust-1',
        name: 'Pak Ahmad',
        phone: '081299998888',
        address: 'Jl. Merdeka No. 5',
        createdAt: now,
        updatedAt: now,
        totalOutstanding: 500000,
      );

      expect(customer.id, equals('cust-1'));
      expect(customer.name, equals('Pak Ahmad'));
      expect(customer.totalOutstanding, equals(500000));

      final map = customer.toMap();
      final restored = Customer.fromMap(map);

      expect(restored.name, equals('Pak Ahmad'));
      expect(restored.totalOutstanding, equals(500000));
    });

    test('Debt model creation and payment status tracking', () {
      final debt = Debt(
        id: 'debt-101',
        transactionId: 'tx-202',
        customerId: 'cust-1',
        customerName: 'Pak Ahmad',
        invoiceNumber: 'INV-20260926-001',
        totalAmount: 1000000,
        paidAmount: 200000,
        remainingBalance: 800000,
        dueDate: dueDate,
        createdAt: now,
        updatedAt: now,
        status: DebtStatus.partiallyPaid,
      );

      expect(debt.totalAmount, equals(1000000));
      expect(debt.paidAmount, equals(200000));
      expect(debt.remainingBalance, equals(800000));
      expect(debt.status, equals(DebtStatus.partiallyPaid));
      expect(debt.isOverdue, isFalse);

      // Simulate full payment
      final paidDebt = debt.copyWith(
        paidAmount: 1000000,
        remainingBalance: 0,
        status: DebtStatus.paid,
      );

      expect(paidDebt.paidAmount, equals(1000000));
      expect(paidDebt.remainingBalance, equals(0));
      expect(paidDebt.status, equals(DebtStatus.paid));
    });

    test('Overdue debt detection logic', () {
      final pastDueDate = now.subtract(const Duration(days: 5));
      final overdueDebt = Debt(
        id: 'debt-102',
        transactionId: 'tx-203',
        customerId: 'cust-1',
        customerName: 'Pak Ahmad',
        invoiceNumber: 'INV-20260926-002',
        totalAmount: 500000,
        paidAmount: 0,
        remainingBalance: 500000,
        dueDate: pastDueDate,
        createdAt: now.subtract(const Duration(days: 35)),
        updatedAt: now,
        status: DebtStatus.unpaid,
      );

      expect(overdueDebt.isOverdue, isTrue);
    });
  });
}
