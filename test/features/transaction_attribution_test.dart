import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/shared/models/transaction.dart';
import 'package:buildera/features/cashier/models/cart_item.dart';
import 'package:buildera/features/debts/models/debt_payment.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tahap 3: Transaction & Debt Payment Cashier Attribution Tests', () {
    test('Transaction stores cashierId and cashierName in toMap and fromMap', () {
      final now = DateTime.now();
      final tx = Transaction(
        id: 'tx-100',
        invoiceNumber: 'INV-20261022-001',
        cashierId: 'admin-uuid-123',
        cashierName: 'Ahmad Kasir',
        subtotal: 100000,
        itemDiscountTotal: 0,
        transDiscountValue: 0,
        transDiscountType: DiscountType.fixed,
        transDiscountAmount: 0,
        taxRate: 0.11,
        taxAmount: 11000,
        total: 111000,
        paymentMethod: 'Tunai',
        amountPaid: 120000,
        changeAmount: 9000,
        createdAt: now,
        updatedAt: now,
      );

      final map = tx.toMap();
      expect(map['cashier_id'], equals('admin-uuid-123'));
      expect(map['cashier_name'], equals('Ahmad Kasir'));

      final restored = Transaction.fromMap(map);
      expect(restored.cashierId, equals('admin-uuid-123'));
      expect(restored.cashierName, equals('Ahmad Kasir'));
    });

    test('DebtPayment stores cashierId and cashierName in toMap and fromMap', () {
      final now = DateTime.now();
      final payment = DebtPayment(
        id: 'pay-200',
        debtId: 'debt-1',
        customerId: 'cust-1',
        amount: 50000,
        createdAt: now,
        notes: 'Pelunasan cicilan 1',
        cashierId: 'admin-uuid-456',
        cashierName: 'Rina Kasir',
      );

      final map = payment.toMap();
      expect(map['cashier_id'], equals('admin-uuid-456'));
      expect(map['cashier_name'], equals('Rina Kasir'));

      final restored = DebtPayment.fromMap(map);
      expect(restored.cashierId, equals('admin-uuid-456'));
      expect(restored.cashierName, equals('Rina Kasir'));
    });
  });
}
