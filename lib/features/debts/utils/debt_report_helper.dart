import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'package:printing/printing.dart';
import '../../../core/utils/formatters.dart';
import '../models/customer.dart';
import '../models/debt.dart';

class DebtReportHelper {
  static Future<void> exportOutstandingToExcel(List<Customer> customers) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Header
      sheet.appendRow([
        TextCellValue('Nama Pelanggan'),
        TextCellValue('Nomor Telepon'),
        TextCellValue('Total Piutang (Rp)'),
        TextCellValue('Status'),
      ]);

      // Data
      for (final c in customers.where((c) => c.totalOutstanding > 0)) {
        sheet.appendRow([
          TextCellValue(c.name),
          TextCellValue(c.phone),
          DoubleCellValue(c.totalOutstanding),
          TextCellValue('Aktif'),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) return;

      final now = DateTime.now();
      final fileName = 'Laporan_Piutang_${now.year}${now.month}${now.day}.xlsx';

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> exportCustomerDetailToExcel(Customer customer, List<Debt> debts) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Sheet1'];

      // Profile Header
      sheet.appendRow([TextCellValue('LAPORAN PIUTANG PELANGGAN')]);
      sheet.appendRow([TextCellValue('Nama:'), TextCellValue(customer.name)]);
      sheet.appendRow([TextCellValue('Telepon:'), TextCellValue(customer.phone)]);
      sheet.appendRow([TextCellValue('Total Piutang:'), DoubleCellValue(customer.totalOutstanding)]);
      sheet.appendRow([]); // Empty row

      // Table Header
      sheet.appendRow([
        TextCellValue('Invoice'),
        TextCellValue('Tgl Transaksi'),
        TextCellValue('Jatuh Tempo'),
        TextCellValue('Total (Rp)'),
        TextCellValue('Terbayar (Rp)'),
        TextCellValue('Sisa (Rp)'),
        TextCellValue('Status'),
      ]);

      // Data
      for (final d in debts) {
        sheet.appendRow([
          TextCellValue(d.invoiceNumber),
          TextCellValue(Formatters.date(d.createdAt)),
          TextCellValue(Formatters.date(d.dueDate)),
          DoubleCellValue(d.totalAmount),
          DoubleCellValue(d.paidAmount),
          DoubleCellValue(d.remainingBalance),
          TextCellValue(d.status.name.toUpperCase()),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) return;

      final fileName = 'Piutang_${customer.name.replaceAll(' ', '_')}.xlsx';

      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename: fileName,
      );
    } catch (e) {
      rethrow;
    }
  }
}
