import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../models/print_document.dart';
import '../models/printer_profile.dart';
import '../../shared/models/transaction.dart';
import '../../features/debts/models/debt.dart';
import '../../features/debts/models/customer.dart';
import '../../features/debts/models/debt_payment.dart';
import '../../features/settings/models/store_settings.dart';
import '../../core/utils/formatters.dart';

class ReceiptLayoutService {
  Future<Uint8List> buildPdf(
      ReceiptDocument receipt, PrinterProfile profile) async {
    final pdf = pw.Document();
    final width = profile.paperWidthMm * PdfPageFormat.mm;
    
    // Extract Metadata
    final tx = receipt.metadata['transaction'] as Transaction?;
    final settings = receipt.metadata['settings'] as StoreSettings?;
    final debt = receipt.metadata['debt'] as Debt?;
    final customer = receipt.metadata['customer'] as Customer?;
    final payments = receipt.metadata['payments'] as List<DebtPayment>?;

    if (settings == null) return Uint8List(0);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, double.infinity, marginAll: profile.marginMm * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Header
              _buildHeader(settings),
              pw.Divider(thickness: 0.5),

              // 2. Info
              if (debt != null && customer != null)
                _buildDebtInfo(customer, debt)
              else if (tx != null)
                _buildTransactionInfo(tx),
              pw.Divider(thickness: 0.5),

              // 3. Items (Sales only)
              if (tx != null) ...[
                _buildItems(tx.items),
                pw.Divider(thickness: 0.5),
              ],

              // 4. Summary
              if (debt != null)
                _buildDebtSummary(debt)
              else if (tx != null)
                _buildTransactionSummary(tx),
              pw.Divider(thickness: 0.5),

              // 5. Payment History (Debt only)
              if (payments != null) ...[
                _buildPaymentHistory(payments),
                pw.Divider(thickness: 0.5),
              ],

              // 6. Conditional Payment Info
              if (debt != null || tx?.paymentMethod == AppConstants.paymentTransfer) ...[
                _buildPaymentInfo(settings),
                pw.Divider(thickness: 0.5),
              ],

              // 7. Final Footer
              _buildFinalFooter(debt != null),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader(StoreSettings s) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(s.businessName.toUpperCase(),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
          pw.SizedBox(height: 2),
          if (s.address.isNotEmpty) pw.Text(s.address, style: const pw.TextStyle(fontSize: 8)),
          if (s.phone.isNotEmpty) pw.Text('Telp: ${s.phone}', style: const pw.TextStyle(fontSize: 8)),
          if (s.email.isNotEmpty) pw.Text(s.email, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _buildTransactionInfo(Transaction tx) {
    final dateStr = Formatters.date(tx.createdAt);
    final timeStr = DateFormat('HH:mm').format(tx.createdAt);

    return pw.Column(
      children: [
        _row('Kasir : ${tx.cashierName ?? 'Admin'}', dateStr, fontSize: 8),
        _row('No    : ${tx.invoiceNumber}', timeStr, fontSize: 8),
      ],
    );
  }

  pw.Widget _buildDebtInfo(Customer c, Debt d) {
    final now = DateTime.now();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _row('Plg : ${c.name}', Formatters.date(now), fontSize: 8),
        if (c.phone.isNotEmpty) pw.Text('Telp: ${c.phone}', style: const pw.TextStyle(fontSize: 8)),
        _row('No  : ${d.invoiceNumber}', DateFormat('HH:mm').format(now), fontSize: 8),
        pw.Text('Jatuh Tempo: ${Formatters.date(d.dueDate)}', style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildItems(List<TransactionItem> items) {
    return pw.Column(
      children: items.map((item) {
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(item.productName, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              _row(
                '${Formatters.decimal(item.quantity)} ${item.unitName} x ${Formatters.currency(item.soldPrice)}',
                Formatters.currency(item.subtotal),
                fontSize: 8,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildTransactionSummary(Transaction tx) {
    final disc = tx.itemDiscountTotal + tx.transDiscountAmount;
    return pw.Column(
      children: [
        _row('Subtotal', Formatters.currency(tx.subtotal), fontSize: 8),
        if (disc > 0) _row('Potongan', '-${Formatters.currency(disc)}', fontSize: 8),
        if (tx.taxAmount > 0) _row('Pajak', Formatters.currency(tx.taxAmount), fontSize: 8),
        if (tx.shippingFee > 0) _row('Ongkir', Formatters.currency(tx.shippingFee), fontSize: 8),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('TOTAL  ${Formatters.currency(tx.total)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        ),
        pw.SizedBox(height: 4),
        _row('Bayar (${tx.paymentMethod})', Formatters.currency(tx.amountPaid), fontSize: 8),
        _row('Kembalian', Formatters.currency(tx.changeAmount), fontSize: 8),
      ],
    );
  }

  pw.Widget _buildDebtSummary(Debt d) {
    return pw.Column(
      children: [
        _row('Total Piutang Awal', Formatters.currency(d.totalAmount), fontSize: 8),
        _row('Total Sudah Bayar', Formatters.currency(d.paidAmount), fontSize: 8),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('SISA PIUTANG  ${Formatters.currency(d.remainingBalance)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
        ),
      ],
    );
  }

  pw.Widget _buildPaymentHistory(List<DebtPayment> payments) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(child: pw.Text('RIWAYAT CICILAN / PEMBAYARAN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8))),
        pw.SizedBox(height: 4),
        if (payments.isEmpty)
          pw.Center(child: pw.Text('Belum ada riwayat pembayaran', style: const pw.TextStyle(fontSize: 8)))
        else
          ...payments.map((p) => _row(Formatters.date(p.createdAt), Formatters.currency(p.amount), fontSize: 8)),
      ],
    );
  }

  pw.Widget _buildPaymentInfo(StoreSettings s) {
    if (s.bankAccounts.isEmpty) return pw.SizedBox();
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text('INFORMASI PEMBAYARAN TRANSFER',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
        ),
        pw.SizedBox(height: 2),
        ...s.bankAccounts.map((acc) => pw.Center(
              child: pw.Text(
                  '${acc.bankName}: ${acc.accountNumber} a/n ${acc.accountHolder}',
                  style: const pw.TextStyle(fontSize: 8)),
            )),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _buildFinalFooter(bool isDebt) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(isDebt ? 'Dokumen ini adalah bukti sah piutang' : 'Terima Kasih atas Kunjungan Anda',
              style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 2),
          pw.Text('Printed: ${Formatters.dateTime(DateTime.now())}', style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
    );
  }

  pw.Widget _row(String left, String right, {double fontSize = 8}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(left, style: pw.TextStyle(fontSize: fontSize)),
        pw.Text(right, style: pw.TextStyle(fontSize: fontSize)),
      ],
    );
  }
}

