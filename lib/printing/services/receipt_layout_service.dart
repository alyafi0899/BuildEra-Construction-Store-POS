import 'dart:typed_data';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/app_constants.dart';
import '../models/print_document.dart';
import '../models/printer_profile.dart';
import '../../shared/models/transaction.dart';
import '../../shared/models/purchase.dart';
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
    final purchase = receipt.metadata['purchase'] as Purchase?;
    final customer = receipt.metadata['customer'] as Customer?;
    final payments = receipt.metadata['payments'] as List<DebtPayment>?;

    if (settings == null) return Uint8List(0);

    final logoBytes = await _loadLogoBytes(settings.logoUrl);
    final design = settings.invoiceDesign;
    final isFast = design == 'fast';
    final baseFontSize = isFast ? 7.0 : 8.0;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(width, double.infinity,
            marginAll: profile.marginMm * PdfPageFormat.mm),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Header
              _buildHeader(settings, design, logoBytes),
              if (!isFast)
                pw.Divider(thickness: 0.5)
              else
                _rawDivider(profile.paperWidthMm),

              // 2. Info
              if (debt != null && customer != null)
                _buildDebtInfo(customer, debt, baseFontSize)
              else if (purchase != null)
                _buildPurchaseInfo(purchase, baseFontSize)
              else if (tx != null)
                _buildTransactionInfo(tx, baseFontSize),
              if (!isFast)
                pw.Divider(thickness: 0.5)
              else
                _rawDivider(profile.paperWidthMm),

              // 3. Items
              if (tx != null && tx.items.isNotEmpty) ...[
                _buildItems(tx.items, baseFontSize, design),
                if (!isFast)
                  pw.Divider(thickness: 0.5)
                else
                  _rawDivider(profile.paperWidthMm),
              ] else if (purchase != null && purchase.items.isNotEmpty) ...[
                _buildPurchaseItems(purchase.items, baseFontSize, design),
                if (!isFast)
                  pw.Divider(thickness: 0.5)
                else
                  _rawDivider(profile.paperWidthMm),
              ],

              // 4. Summary
              if (debt != null)
                _buildDebtSummary(debt, baseFontSize, design, tx: tx)
              else if (purchase != null)
                _buildPurchaseSummary(purchase, baseFontSize, design)
              else if (tx != null)
                _buildTransactionSummary(tx, baseFontSize, design),
              if (!isFast)
                pw.Divider(thickness: 0.5)
              else
                _rawDivider(profile.paperWidthMm),

              // 4.1 Notes
              if ((tx?.notes?.isNotEmpty ?? false) ||
                  (debt?.notes?.isNotEmpty ?? false) ||
                  (purchase?.notes?.isNotEmpty ?? false)) ...[
                _buildNotes(tx?.notes ?? debt?.notes ?? purchase?.notes ?? '',
                    baseFontSize),
                if (!isFast)
                  pw.Divider(thickness: 0.5)
                else
                  _rawDivider(profile.paperWidthMm),
              ],

              // 5. Payment History (Debt only)
              if (payments != null && payments.isNotEmpty) ...[
                _buildPaymentHistory(payments, baseFontSize),
                if (!isFast)
                  pw.Divider(thickness: 0.5)
                else
                  _rawDivider(profile.paperWidthMm),
              ],

              // 6. Conditional Payment Info (Banks)
              if (debt != null ||
                  tx?.paymentMethod == AppConstants.paymentTransfer ||
                  tx?.paymentMethod == AppConstants.paymentPiutang) ...[
                _buildPaymentInfo(settings, baseFontSize),
                if (!isFast)
                  pw.Divider(thickness: 0.5)
                else
                  _rawDivider(profile.paperWidthMm),
              ],

              // 7. Final Footer
              _buildFinalFooter(debt != null, baseFontSize),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _rawDivider(double widthMm) {
    final count = widthMm < 60 ? 32 : 48;
    return pw.Text('-' * count, style: const pw.TextStyle(fontSize: 7));
  }

  pw.Widget _buildHeader(StoreSettings s, String design, Uint8List? logoBytes) {
    final isModern = design == 'modern';
    return pw.Center(
      child: pw.Column(
        children: [
          if (logoBytes != null && logoBytes.isNotEmpty)
            pw.Container(
              width: 80,
              height: 80,
              child:
                  pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
            )
          else
            pw.Text(s.businessName.toUpperCase(),
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: isModern ? 16 : 14)),
          if (logoBytes != null && logoBytes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(s.businessName.toUpperCase(),
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: isModern ? 16 : 14)),
          ],
          pw.SizedBox(height: 2),
          if (s.address.isNotEmpty)
            pw.Text(s.address,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: isModern ? 9 : 8)),
          if (s.phone.isNotEmpty)
            pw.Text('Telp: ${s.phone}',
                style: pw.TextStyle(fontSize: isModern ? 9 : 8)),
          if (s.email.isNotEmpty)
            pw.Text(s.email, style: pw.TextStyle(fontSize: isModern ? 9 : 8)),
          if (isModern) pw.SizedBox(height: 4),
        ],
      ),
    );
  }

  Future<Uint8List?> _loadLogoBytes(String? logoPath) async {
    if (logoPath == null || logoPath.isEmpty) return null;

    try {
      final resolved = await _resolvePath(logoPath);
      if (resolved == null) return null;
      final file = File(resolved);
      if (await file.exists()) return await file.readAsBytes();
    } catch (_) {}

    return null;
  }

  Future<String?> _resolvePath(String? storedPath) async {
    if (storedPath == null || storedPath.isEmpty) return null;
    final file = File(storedPath);
    if (await file.exists()) return storedPath;

    final appDir = await getApplicationSupportDirectory();
    final candidate = storedPath.replaceAll('\\', '/');
    final normalized = candidate.contains('BuildEra_Offline')
        ? candidate.substring(candidate.indexOf('BuildEra_Offline'))
        : candidate;
    final supportCandidate = '${appDir.path}/$normalized';
    final supportFile = File(supportCandidate);
    if (await supportFile.exists()) return supportFile.path;

    return null;
  }

  pw.Widget _buildTransactionInfo(Transaction tx, double fontSize) {
    final dateStr = Formatters.date(tx.createdAt);
    final timeStr = DateFormat('HH:mm').format(tx.createdAt);

    return pw.Column(
      children: [
        _row('Kasir : ${tx.cashierName ?? 'Admin'}', dateStr,
            fontSize: fontSize),
        _row('No    : ${tx.invoiceNumber}', timeStr, fontSize: fontSize),
      ],
    );
  }

  pw.Widget _buildPurchaseInfo(Purchase purchase, double fontSize) {
    final dateStr = Formatters.date(purchase.createdAt);
    final timeStr = DateFormat('HH:mm').format(purchase.createdAt);

    return pw.Column(
      children: [
        pw.Center(
            child: pw.Text('NOTA MASUK (PEMBELIAN)',
                style: pw.TextStyle(
                    fontSize: fontSize, fontWeight: pw.FontWeight.bold))),
        pw.SizedBox(height: 4),
        _row('Staff : ${purchase.staffName ?? 'Admin'}', dateStr,
            fontSize: fontSize),
        _row('Supp  : ${purchase.supplierName ?? 'Umum'}', timeStr,
            fontSize: fontSize),
        _row('No    : ${purchase.invoiceNumber}', '', fontSize: fontSize),
      ],
    );
  }

  pw.Widget _buildDebtInfo(Customer c, Debt d, double fontSize) {
    final now = DateTime.now();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _row('Plg : ${c.name}', Formatters.date(now), fontSize: fontSize),
        if (c.phone.isNotEmpty)
          pw.Text('Telp: ${c.phone}', style: pw.TextStyle(fontSize: fontSize)),
        _row('No  : ${d.invoiceNumber}', DateFormat('HH:mm').format(now),
            fontSize: fontSize),
        pw.Text('Jatuh Tempo: ${Formatters.date(d.dueDate)}',
            style: pw.TextStyle(fontSize: fontSize)),
      ],
    );
  }

  pw.Widget _buildItems(
      List<TransactionItem> items, double fontSize, String design) {
    final isModern = design == 'modern';
    return pw.Column(
      children: items.map((item) {
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: isModern ? 6 : 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(item.productName,
                  style: pw.TextStyle(
                      fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
              _row(
                '${Formatters.decimal(item.quantity)} ${item.unitName} x ${Formatters.currency(item.soldPrice)}',
                Formatters.currency(item.subtotal),
                fontSize: fontSize,
              ),
              if (item.totalDiscount > 0)
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                      '(Disc: -${Formatters.currency(item.totalDiscount)})',
                      style: pw.TextStyle(
                          fontSize: fontSize - 1)), // Removed italic
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildPurchaseItems(
      List<PurchaseItem> items, double fontSize, String design) {
    final isModern = design == 'modern';
    return pw.Column(
      children: items.map((item) {
        return pw.Padding(
          padding: pw.EdgeInsets.only(bottom: isModern ? 6 : 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(item.productName,
                  style: pw.TextStyle(
                      fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
              _row(
                '${Formatters.decimal(item.quantity)} ${item.unitName} x ${Formatters.currency(item.purchasePrice)}',
                Formatters.currency(item.subtotal),
                fontSize: fontSize,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildTransactionSummary(
      Transaction tx, double fontSize, String design) {
    final disc = tx.itemDiscountTotal + tx.transDiscountAmount;
    final isModern = design == 'modern';

    return pw.Column(
      children: [
        _row('Subtotal', Formatters.currency(tx.subtotal), fontSize: fontSize),
        if (disc > 0)
          _row('Potongan', '-${Formatters.currency(disc)}', fontSize: fontSize),
        if (tx.taxAmount > 0)
          _row('Pajak (PPN)', Formatters.currency(tx.taxAmount),
              fontSize: fontSize),
        if (tx.shippingFee > 0)
          _row('Ongkir', Formatters.currency(tx.shippingFee),
              fontSize: fontSize),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('TOTAL  ${Formatters.currency(tx.total)}',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: isModern ? 14 : 12)),
        ),
        pw.SizedBox(height: 4),
        _row('Bayar (${tx.paymentMethod})', Formatters.currency(tx.amountPaid),
            fontSize: fontSize),
        _row('Kembalian', Formatters.currency(tx.changeAmount),
            fontSize: fontSize),
      ],
    );
  }

  pw.Widget _buildPurchaseSummary(
      Purchase purchase, double fontSize, String design) {
    final isModern = design == 'modern';

    return pw.Column(
      children: [
        _row('Subtotal', Formatters.currency(purchase.subtotal),
            fontSize: fontSize),
        if (purchase.shippingFee > 0)
          _row('Biaya Kirim', Formatters.currency(purchase.shippingFee),
              fontSize: fontSize),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('TOTAL  ${Formatters.currency(purchase.total)}',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: isModern ? 14 : 12)),
        ),
        pw.SizedBox(height: 4),
        _row('Bayar (${purchase.paymentMethod})',
            Formatters.currency(purchase.amountPaid),
            fontSize: fontSize),
        if (purchase.total > purchase.amountPaid)
          _row('Sisa Hutang',
              Formatters.currency(purchase.total - purchase.amountPaid),
              fontSize: fontSize, color: PdfColors.red900),
      ],
    );
  }

  pw.Widget _buildDebtSummary(Debt d, double fontSize, String design,
      {Transaction? tx}) {
    final isModern = design == 'modern';
    return pw.Column(
      children: [
        _row('Total Piutang Awal', Formatters.currency(d.totalAmount),
            fontSize: fontSize),
        if (tx != null && tx.shippingFee > 0)
          _row('Termasuk Ongkir', Formatters.currency(tx.shippingFee),
              fontSize: fontSize),
        _row('Total Sudah Bayar', Formatters.currency(d.paidAmount),
            fontSize: fontSize),
        pw.SizedBox(height: 4),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
              'SISA PIUTANG  ${Formatters.currency(d.remainingBalance)}',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: isModern ? 14 : 12)),
        ),
      ],
    );
  }

  pw.Widget _buildPaymentHistory(List<DebtPayment> payments, double fontSize) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
            child: pw.Text('RIWAYAT CICILAN',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: fontSize))),
        pw.SizedBox(height: 4),
        ...payments.map((p) => _row(
            Formatters.date(p.createdAt), Formatters.currency(p.amount),
            fontSize: fontSize)),
      ],
    );
  }

  pw.Widget _buildPaymentInfo(StoreSettings s, double fontSize) {
    if (s.bankAccounts.isEmpty) return pw.SizedBox();
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text('PEMBAYARAN TRANSFER',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, fontSize: fontSize)),
        ),
        pw.SizedBox(height: 2),
        ...s.bankAccounts.map((acc) => pw.Center(
              child: pw.Text(
                  '${acc.bankName}: ${acc.accountNumber} a/n ${acc.accountHolder}',
                  style: pw.TextStyle(fontSize: fontSize - 1)),
            )),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _buildFinalFooter(bool isDebt, double fontSize) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(
              isDebt
                  ? 'Dokumen ini adalah bukti sah piutang'
                  : 'Terima Kasih atas Kunjungan Anda',
              style: pw.TextStyle(fontSize: fontSize)),
          pw.SizedBox(height: 2),
          pw.Text('Waktu Cetak: ${Formatters.dateTime(DateTime.now())}',
              style: pw.TextStyle(fontSize: fontSize - 1)), // Removed italic
        ],
      ),
    );
  }

  pw.Widget _buildNotes(String notes, double fontSize) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Keterangan:',
            style: pw.TextStyle(
                fontSize: fontSize, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 1),
        pw.Text(notes, style: pw.TextStyle(fontSize: fontSize)),
      ],
    );
  }

  pw.Widget _row(String left, String right,
      {double fontSize = 8, PdfColor? color}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(left, style: pw.TextStyle(fontSize: fontSize, color: color)),
        pw.Text(right, style: pw.TextStyle(fontSize: fontSize, color: color)),
      ],
    );
  }
}
