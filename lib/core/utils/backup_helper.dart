import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/transaction.dart';
import '../../features/inventory/models/restock_record.dart';
import '../../features/inventory/models/bill_payment.dart';
import '../../features/debts/models/customer.dart';
import '../../features/debts/models/debt.dart';
import '../../features/debts/models/debt_payment.dart';
import '../../shared/widgets/common_widgets.dart';
import 'formatters.dart';
import '../../features/settings/models/store_settings.dart';

class BackupHelper {
  /// Consolidates all data into ONE single Excel file with multiple sheets
  static Future<void> performFullBackup({
    required BuildContext context,
    required List<Product> products,
    required List<RestockRecord> restocks,
    required List<BillPayment> billPayments,
    required List<Customer> customers,
    required List<Debt> customerDebts,
    required List<DebtPayment> customerPayments,
    required List<Transaction> transactions,
    required StoreSettings settings,
  }) async {
    debugPrint('BackupHelper: Starting consolidated backup...');
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'BuildEra_MASTER_BACKUP_$timestamp.xlsx';

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Menyusun Master Backup Excel...'), duration: Duration(seconds: 3))
        );
      }

      final excel = Excel.createExcel();
      
      // ── SHEET 1: MASTER PRODUCT ──────────────────────────────────────────
      Sheet sProd = excel['1. Master Produk'];
      sProd.appendRow([
        TextCellValue('NAMA PRODUK'), 
        TextCellValue('BARCODE'), 
        TextCellValue('KATEGORI'), 
        TextCellValue('STOK'), 
        TextCellValue('SATUAN DASAR'), 
        TextCellValue('MODAL (LAST)'), 
        TextCellValue('JUAL (DASAR)'),
        TextCellValue('HUTANG SUPPLIER'), // Initial batch status
        TextCellValue('SISA HUTANG SUPPLIER'),
        TextCellValue('HUTANG ONGKIR'),
        TextCellValue('SISA HUTANG ONGKIR'),
      ]);

      for (var p in products) {
        final f = p.financials;
        sProd.appendRow([
          TextCellValue(p.name), 
          TextCellValue(p.barcode ?? '-'), 
          TextCellValue(p.category), 
          DoubleCellValue(p.stock), 
          TextCellValue(p.baseUnit), 
          DoubleCellValue(p.costPrice), 
          DoubleCellValue(p.basePrice),
          TextCellValue(f.supplierPaymentStatus.name.toUpperCase()),
          DoubleCellValue(f.supplierPrice - f.supplierPaidAmount),
          TextCellValue(f.shippingPaymentStatus.name.toUpperCase()),
          DoubleCellValue(f.supplierShippingCost - f.shippingPaidAmount),
        ]);
      }

      // ── SHEET 2: RIWAYAT RESTOCK (LOG PENGADAAN) ─────────────────────────
      Sheet sRestock = excel['2. Riwayat Restock'];
      sRestock.appendRow([
        TextCellValue('TANGGAL'), 
        TextCellValue('PRODUK'), 
        TextCellValue('QTY'), 
        TextCellValue('SATUAN'), 
        TextCellValue('SUPPLIER'), 
        TextCellValue('TOTAL BELI'), 
        TextCellValue('ONGKIR'), 
        TextCellValue('TOTAL MODAL'),
        TextCellValue('STATUS SUPPLIER'),
        TextCellValue('SISA SUPPLIER'),
        TextCellValue('STATUS ONGKIR'),
        TextCellValue('SISA ONGKIR'),
        TextCellValue('CATATAN')
      ]);

      for (var r in restocks) {
        sRestock.appendRow([
          TextCellValue(Formatters.dateTime(r.createdAt)),
          TextCellValue(r.productName),
          DoubleCellValue(r.quantityAdded),
          TextCellValue(r.unitName),
          TextCellValue(r.supplierName ?? 'Umum'),
          DoubleCellValue(r.supplierPrice),
          DoubleCellValue(r.shippingCost),
          DoubleCellValue(r.supplierPrice + r.shippingCost),
          TextCellValue(r.supplierPaymentStatus.name.toUpperCase()),
          DoubleCellValue(r.supplierPrice - r.supplierPaidAmount),
          TextCellValue(r.shippingPaymentStatus.name.toUpperCase()),
          DoubleCellValue(r.shippingCost - r.shippingPaidAmount),
          TextCellValue(r.notes ?? '-'),
        ]);
      }

      // ── SHEET 3: SEMUA INVOICE PENJUALAN ──────────────────────────────────
      Sheet sInv = excel['3. Invoice Penjualan'];
      sInv.appendRow([
        TextCellValue('TANGGAL'), 
        TextCellValue('INVOICE'), 
        TextCellValue('PELANGGAN'), 
        TextCellValue('METODE BAYAR'), 
        TextCellValue('SUBTOTAL'), 
        TextCellValue('DISKON'), 
        TextCellValue('PPN'), 
        TextCellValue('TOTAL AKHIR'), 
        TextCellValue('DIBAYAR'), 
        TextCellValue('KEMBALI'),
        TextCellValue('KASIR')
      ]);

      for (var t in transactions) {
        sInv.appendRow([
          TextCellValue(Formatters.dateTime(t.createdAt)),
          TextCellValue(t.invoiceNumber),
          TextCellValue(t.customerName ?? 'Umum'),
          TextCellValue(t.paymentMethod),
          DoubleCellValue(t.subtotal),
          DoubleCellValue(t.itemDiscountTotal + t.transDiscountAmount),
          DoubleCellValue(t.taxAmount),
          DoubleCellValue(t.total),
          DoubleCellValue(t.amountPaid),
          DoubleCellValue(t.changeAmount),
          TextCellValue(t.cashierName ?? 'Admin'),
        ]);
      }

      // ── SHEET 4: RINCIAN ITEM TERJUAL ─────────────────────────────────────
      Sheet sItem = excel['4. Rincian Item Terjual'];
      sItem.appendRow([
        TextCellValue('INVOICE'), 
        TextCellValue('PRODUK'), 
        TextCellValue('QTY'), 
        TextCellValue('SATUAN'), 
        TextCellValue('HARGA JUAL'), 
        TextCellValue('SUBTOTAL'), 
        TextCellValue('MODAL UNIT'), 
        TextCellValue('PROFIT ITEM')
      ]);

      for (var t in transactions) {
        for (var item in t.items) {
          final profit = item.subtotal - (item.costPrice * item.quantity);
          sItem.appendRow([
            TextCellValue(t.invoiceNumber),
            TextCellValue(item.productName),
            DoubleCellValue(item.quantity),
            TextCellValue(item.unitName),
            DoubleCellValue(item.soldPrice),
            DoubleCellValue(item.subtotal),
            DoubleCellValue(item.costPrice),
            DoubleCellValue(profit),
          ]);
        }
      }

      // ── SHEET 5: PIUTANG PELANGGAN ────────────────────────────────────────
      Sheet sDebt = excel['5. Piutang Pelanggan'];
      sDebt.appendRow([
        TextCellValue('PELANGGAN'), 
        TextCellValue('TELEPON'), 
        TextCellValue('TOTAL PIUTANG AKTIF'), 
        TextCellValue('ALAMAT')
      ]);

      for (var c in customers) {
        sDebt.appendRow([
          TextCellValue(c.name),
          TextCellValue(c.phone),
          DoubleCellValue(c.totalOutstanding),
          TextCellValue(c.address ?? '-'),
        ]);
      }

      // ── SHEET 6: RIWAYAT CICILAN HUTANG ───────────────────────────────────
      Sheet sPay = excel['6. Log Cicilan Hutang Toko'];
      sPay.appendRow([
        TextCellValue('TANGGAL'), 
        TextCellValue('NAMA BATCH/PRODUK'), 
        TextCellValue('JUMLAH BAYAR'), 
        TextCellValue('KETERANGAN'), 
        TextCellValue('JENIS BATCH')
      ]);

      // Optimization: Create lookup maps to avoid O(N^2) search in large datasets
      final prodMap = {for (var p in products) p.id: p.name};
      final restockMap = {for (var r in restocks) r.id: r.productName};

      for (var p in billPayments) {
        String targetName = 'ID: ${p.billId}';
        if (p.isInitialBill) {
          targetName = prodMap[p.billId] ?? targetName;
        } else {
          targetName = restockMap[p.billId] ?? targetName;
        }

        sPay.appendRow([
          TextCellValue(Formatters.dateTime(p.createdAt)),
          TextCellValue(targetName),
          DoubleCellValue(p.amount),
          TextCellValue(p.notes ?? 'Cicilan'),
          TextCellValue(p.isInitialBill ? 'STOK AWAL' : 'RESTOCK BATCH'),
        ]);
      }

      // Save and finish
      final bytes = excel.save();
      if (bytes != null) {
        await Printing.sharePdf(
          bytes: Uint8List.fromList(bytes),
          filename: fileName,
        );
        debugPrint('Consolidated backup successfully generated and shared.');
      }

    } catch (e, stack) {
      debugPrint('Consolidated Backup Error: $e\n$stack');
      if (context.mounted) showError(context, 'Gagal menyusun backup: $e');
    }
  }
}
