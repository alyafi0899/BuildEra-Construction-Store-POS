import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/shared/models/transaction.dart';
import 'package:buildera/shared/models/purchase.dart';
import 'package:buildera/features/inventory/models/restock_record.dart';
import 'package:buildera/features/inventory/models/bill_payment.dart';
import 'package:buildera/features/products/models/supplier.dart';
import 'package:buildera/features/products/models/shipping_service.dart';
import 'package:buildera/features/products/models/print_profile.dart';
import 'package:buildera/features/products/models/product_financials.dart';
import 'package:buildera/features/settings/models/app_settings.dart';
import 'package:buildera/features/cashier/models/cart_item.dart';

void main() {
  final now = DateTime.now();

  group('Domain Models & Entities Tests', () {
    test('Transaction and TransactionItem serialization toMap and fromMap', () {
      final item = TransactionItem(
        id: 'tx-item-1',
        transactionId: 'tx-100',
        productId: 'prod-1',
        productName: 'Cat Tembok 5kg',
        unitName: 'kaleng',
        conversionRate: 1.0,
        quantity: 3,
        costPrice: 80000,
        originalPrice: 120000,
        soldPrice: 110000,
        discountValue: 10000,
        discountType: DiscountType.fixed,
        subtotal: 330000,
      );

      final itemMap = item.toMap();
      expect(itemMap['id'], equals('tx-item-1'));
      expect(itemMap['discount_type'], equals('fixed'));

      final restoredItem = TransactionItem.fromMap(itemMap);
      expect(restoredItem.productName, equals('Cat Tembok 5kg'));
      expect(restoredItem.subtotal, equals(330000));
      expect(restoredItem.totalDiscount, equals(30000));

      final tx = Transaction(
        id: 'tx-100',
        invoiceNumber: 'INV-20261017-001',
        customerId: 'cust-10',
        customerName: 'Budi Santoso',
        cashierName: 'Kasir Utama',
        subtotal: 330000,
        itemDiscountTotal: 30000,
        transDiscountValue: 10000,
        transDiscountType: DiscountType.fixed,
        transDiscountAmount: 10000,
        taxRate: 0.11,
        taxAmount: 35200,
        shippingFee: 15000,
        total: 370200,
        paymentMethod: 'cash',
        amountPaid: 400000,
        changeAmount: 29800,
        notes: 'Pengiriman sore',
        createdAt: now,
        updatedAt: now,
        items: [item],
      );

      final txMap = tx.toMap();
      expect(txMap['invoice_number'], equals('INV-20261017-001'));
      expect(txMap['shipping_fee'], equals(15000));

      final restoredTx = Transaction.fromMap(txMap, items: [restoredItem]);
      expect(restoredTx.invoiceNumber, equals('INV-20261017-001'));
      expect(restoredTx.customerName, equals('Budi Santoso'));
      expect(restoredTx.items.length, equals(1));
      expect(restoredTx.total, equals(370200));
    });

    test('Purchase and PurchaseItem serialization toMap and fromMap', () {
      final item = PurchaseItem(
        id: 'pur-item-1',
        purchaseId: 'pur-50',
        productId: 'prod-2',
        productName: 'Batu Bata Merah',
        unitName: 'biji',
        conversionRate: 1.0,
        quantity: 1000,
        purchasePrice: 800,
        subtotal: 800000,
      );

      final itemMap = item.toMap();
      final restoredItem = PurchaseItem.fromMap(itemMap);
      expect(restoredItem.productName, equals('Batu Bata Merah'));
      expect(restoredItem.subtotal, equals(800000));

      final purchase = Purchase(
        id: 'pur-50',
        invoiceNumber: 'PUR-20261017-001',
        supplierId: 'sup-1',
        supplierName: 'PT Material Utama',
        staffName: 'Admin Warehouse',
        subtotal: 800000,
        shippingFee: 50000,
        total: 850000,
        paymentMethod: 'transfer',
        amountPaid: 850000,
        paymentStatus: PaymentStatus.paid,
        notes: 'Lunas via transfer',
        createdAt: now,
        updatedAt: now,
        items: [item],
      );

      final purchaseMap = purchase.toMap();
      expect(purchaseMap['payment_status'], equals('paid'));

      final restoredPurchase = Purchase.fromMap(purchaseMap, items: [restoredItem]);
      expect(restoredPurchase.supplierName, equals('PT Material Utama'));
      expect(restoredPurchase.paymentStatus, equals(PaymentStatus.paid));
      expect(restoredPurchase.total, equals(850000));
    });

    test('RestockRecord serialization, copyWith, and payment status tracking', () {
      final restock = RestockRecord(
        id: 'restock-1',
        productId: 'prod-1',
        productName: 'Semen Gresik 50kg',
        quantityAdded: 50,
        unitName: 'sak',
        supplierPrice: 55000,
        shippingCost: 2000,
        totalCostPerUnit: 57000,
        sellingPrice: 65000,
        supplierPaidAmount: 2750000,
        shippingPaidAmount: 100000,
        supplierName: 'PT Semen Indonesia',
        supplierPaymentStatus: PaymentStatus.paid,
        shippingServiceName: 'Ekspedisi Jaya',
        shippingPaymentStatus: PaymentStatus.paid,
        createdAt: now,
      );

      final map = restock.toMap();
      expect(map['supplier_payment_status'], equals('paid'));

      final restored = RestockRecord.fromMap(map);
      expect(restored.supplierName, equals('PT Semen Indonesia'));
      expect(restored.supplierPaymentStatus, equals(PaymentStatus.paid));
      expect(restored.totalCostPerUnit, equals(57000));

      final updated = restock.copyWith(
        supplierPaidAmount: 1000000,
        supplierPaymentStatus: PaymentStatus.partial,
      );
      expect(updated.supplierPaidAmount, equals(1000000));
      expect(updated.supplierPaymentStatus, equals(PaymentStatus.partial));
    });

    test('BillPayment serialization and copyWith', () {
      final payment = BillPayment(
        id: 'pay-1',
        billId: 'bill-10',
        amount: 500000,
        notes: 'Cicilan ke-1',
        createdAt: now,
        isInitialBill: false,
        isForSupplier: true,
      );

      final map = payment.toMap();
      expect(map['is_for_supplier'], isTrue);

      final restored = BillPayment.fromMap(map);
      expect(restored.amount, equals(500000));
      expect(restored.isForSupplier, isTrue);

      final shippingPayment = payment.copyWith(isForSupplier: false, notes: 'Bayar Ongkir');
      expect(shippingPayment.isForSupplier, isFalse);
      expect(shippingPayment.notes, equals('Bayar Ongkir'));
    });

    test('Supplier and ShippingService serialization, copyWith, and equality', () {
      final supplier1 = Supplier(
        id: 'sup-10',
        name: 'Toko Besi Abadi',
        phone: '081122334455',
        address: 'Jl. Industri No. 8',
        createdAt: now,
      );

      final supplier2 = Supplier(
        id: 'sup-10',
        name: 'Toko Besi Abadi',
        phone: '081122334455',
        address: 'Jl. Industri No. 8',
        createdAt: now,
      );

      expect(supplier1, equals(supplier2));
      expect(supplier1.hashCode, equals(supplier2.hashCode));

      final supMap = supplier1.toMap();
      final restoredSup = Supplier.fromMap(supMap);
      expect(restoredSup.name, equals('Toko Besi Abadi'));

      final updatedSup = supplier1.copyWith(name: 'Toko Besi Utama');
      expect(updatedSup.name, equals('Toko Besi Utama'));

      final service = ShippingService(
        id: 'ship-1',
        name: 'Kargo Cepat',
        phone: '081999888777',
        createdAt: now,
      );

      final serviceMap = service.toMap();
      final restoredService = ShippingService.fromMap(serviceMap);
      expect(restoredService.name, equals('Kargo Cepat'));
    });

    test('PrintProfile default values, serialization, and fromMap casting', () {
      final profile = PrintProfile(
        id: 'profile-1',
        name: 'Label Stiker 40x30',
        labelWidth: 40,
        labelHeight: 30,
        columnCount: 3,
        isRollMode: true,
      );

      final map = profile.toMap();
      expect(map['is_roll_mode'], isTrue);
      expect(map['column_count'], equals(3));

      final restored = PrintProfile.fromMap(map);
      expect(restored.name, equals('Label Stiker 40x30'));
      expect(restored.labelWidth, equals(40));
      expect(restored.isRollMode, isTrue);

      // Test fallback defaults for empty map
      final defaultProfile = PrintProfile.fromMap({});
      expect(defaultProfile.paperWidth, equals(210));
      expect(defaultProfile.columnCount, equals(4));
      expect(defaultProfile.isRollMode, isFalse);
    });

    test('AppSettings copyWith behavior', () {
      const settings = AppSettings();
      expect(settings.isFullScreen, isFalse);
      expect(settings.displayScale, equals(1.0));

      final updated = settings.copyWith(
        isFullScreen: true,
        displayScale: 1.25,
      );
      expect(updated.isFullScreen, isTrue);
      expect(updated.displayScale, equals(1.25));
      expect(updated.isCustomerDisplayEnabled, isFalse);
    });
  });
}
