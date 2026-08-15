import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/transaction.dart';
import '../../../features/debts/models/debt.dart';
import '../../../features/debts/models/customer.dart';
import '../../../features/debts/models/debt_payment.dart';
import '../../../features/settings/models/store_settings.dart';
import '../../models/print_document.dart';
import '../../models/printer_profile.dart';

class EscPosDriver {
  PrintResult printReceipt(ReceiptDocument receipt, PrinterProfile profile) {
    try {
      final builder = EscPosBuilder(profile.paperWidthMm);
      final sectionBuilder = ReceiptSectionBuilder(builder);

      // Extract Data from Metadata
      final tx = receipt.metadata['transaction'] as Transaction?;
      final settings = receipt.metadata['settings'] as StoreSettings?;
      final debt = receipt.metadata['debt'] as Debt?;
      final customer = receipt.metadata['customer'] as Customer?;
      final payments = receipt.metadata['payments'] as List<DebtPayment>?;

      if (settings == null) throw 'Store settings missing from metadata';

      // 1. HEADER
      sectionBuilder.buildHeader(settings);

      // 2. INFORMATION SECTION
      if (debt != null && customer != null) {
        sectionBuilder.buildDebtInfo(customer, debt);
      } else if (tx != null) {
        sectionBuilder.buildTransactionInfo(tx);
      }

      // 3. ITEM SECTION
      if (tx != null) {
        sectionBuilder.buildItems(tx.items);
      }

      // 4. SUMMARY SECTION
      if (debt != null) {
        sectionBuilder.buildDebtSummary(debt);
      } else if (tx != null) {
        sectionBuilder.buildTransactionSummary(tx);
      }

      // 5. PAYMENT HISTORY (For Debt)
      if (payments != null) {
        sectionBuilder.buildPaymentHistory(payments);
      }

      // 6. CONDITIONAL PAYMENT INFO
      final isTransfer = tx?.paymentMethod == AppConstants.paymentTransfer;
      if (debt != null || isTransfer) {
        sectionBuilder.buildPaymentInfo(settings);
      }

      // 7. FINAL FOOTER
      sectionBuilder.buildFinalFooter(isDebt: debt != null);

      final bytes = builder.build();

      return PrintResult(
        success: true,
        message: 'ESC/POS receipt generated',
        bytes: bytes,
        payload: 'ESC/POS Native Data',
      );
    } catch (e) {
      return PrintResult(
        success: false,
        message: 'Failed to generate ESC/POS receipt: $e',
      );
    }
  }

  PrintResult printLabel(LabelDocument label, PrinterProfile profile) {
    // Labels might still use simple text or TSPL/ZPL usually
    return PrintResult(
      success: true,
      message: 'ESC/POS label payload generated',
      payload: label.title,
      previewText: label.title,
    );
  }
}

/// A builder for low-level ESC/POS commands
class EscPosBuilder {
  final List<int> _bytes = [];
  final int charsPerLine;

  EscPosBuilder(double widthMm) : charsPerLine = widthMm <= 60 ? 32 : 48 {
    _init();
  }

  void _init() {
    _bytes.addAll([0x1B, 0x40]); // Initialize
    _bytes.addAll([0x1B, 0x74, 0x00]); // Select character code table (PC437)
  }

  void resetStyle() {
    _bytes.addAll([0x1B, 0x21, 0x00]); // Font A, normal
  }

  void setBold(bool bold) {
    _bytes.addAll([0x1B, 0x45, bold ? 0x01 : 0x00]);
  }

  void setFontSize({bool doubleWidth = false, bool doubleHeight = false}) {
    int size = 0;
    if (doubleWidth) size |= 0x20;
    if (doubleHeight) size |= 0x10;
    _bytes.addAll([0x1D, 0x21, size]);
  }

  void setAlign(int align) {
    // 0: Left, 1: Center, 2: Right
    _bytes.addAll([0x1B, 0x61, align]);
  }

  void text(String text, {bool newline = true}) {
    _bytes.addAll(latin1.encode(text));
    if (newline) _bytes.add(0x0A);
  }

  void line(String char) {
    text(char * charsPerLine);
  }

  void emptyLine() {
    _bytes.add(0x0A);
  }

  void cut() {
    _bytes.addAll([0x1D, 0x56, 0x01]);
  }

  Uint8List build() {
    emptyLine();
    emptyLine();
    emptyLine();
    cut();
    return Uint8List.fromList(_bytes);
  }

  /// Splits a text into two parts (left and right aligned)
  void row(String left, String right) {
    int spaces = charsPerLine - (left.length + right.length);
    if (spaces < 1) {
      text(left);
      text(right.padLeft(charsPerLine));
    } else {
      text(left + (' ' * spaces) + right);
    }
  }
}

/// A high-level builder for BuildEra receipt sections
class ReceiptSectionBuilder {
  final EscPosBuilder b;

  ReceiptSectionBuilder(this.b);

  void buildHeader(StoreSettings s) {
    b.setAlign(1);
    b.setFontSize(doubleWidth: true, doubleHeight: true);
    b.setBold(true);
    b.text(s.businessName.toUpperCase());

    b.resetStyle();
    b.setAlign(1);
    if (s.address.isNotEmpty) b.text(s.address);
    if (s.phone.isNotEmpty) b.text('Telp: ${s.phone}');
    if (s.email.isNotEmpty) b.text(s.email);

    b.emptyLine();
    b.line('-');
  }

  void buildTransactionInfo(Transaction tx) {
    b.resetStyle();
    b.setAlign(0);

    final dateStr = Formatters.date(tx.createdAt);
    final timeStr = DateFormat('HH:mm').format(tx.createdAt);

    b.row('Kasir : ${tx.cashierName ?? 'Admin'}', dateStr);
    b.row('No    : ${tx.invoiceNumber}', timeStr);

    b.emptyLine();
    b.line('-');
  }

  void buildDebtInfo(Customer c, Debt d) {
    b.resetStyle();
    b.setAlign(0);

    final now = DateTime.now();
    final dateStr = Formatters.date(now);
    final timeStr = DateFormat('HH:mm').format(now);

    b.row('Plg : ${c.name}', dateStr);
    if (c.phone.isNotEmpty) b.text('Telp: ${c.phone}');
    b.row('No  : ${d.invoiceNumber}', timeStr);
    b.text('Jatuh Tempo: ${Formatters.date(d.dueDate)}');

    b.emptyLine();
    b.line('-');
  }

  void buildItems(List<TransactionItem> items) {
    b.resetStyle();
    for (final item in items) {
      // Line 1: Name (wrapped if needed)
      final nameLines = _wrapText(item.productName, b.charsPerLine);
      for (final nLine in nameLines) {
        b.text(nLine);
      }

      // Line 2: Qty x Price ... Subtotal
      final qtyStr = '${Formatters.decimal(item.quantity)} ${item.unitName} x ${Formatters.currency(item.soldPrice)}';
      final subtotalStr = Formatters.currency(item.subtotal);
      b.row(qtyStr, subtotalStr);

      b.emptyLine();
    }
    b.line('-');
  }

  void buildTransactionSummary(Transaction tx) {
    b.resetStyle();
    b.setAlign(0);

    b.row('Subtotal', Formatters.currency(tx.subtotal));

    final disc = tx.itemDiscountTotal + tx.transDiscountAmount;
    if (disc > 0) {
      b.row('Potongan', '-${Formatters.currency(disc)}');
    }

    if (tx.taxAmount > 0) {
      b.row('Pajak', Formatters.currency(tx.taxAmount));
    }

    if (tx.shippingFee > 0) {
      b.row('Ongkir', Formatters.currency(tx.shippingFee));
    }

    // TOTAL
    b.emptyLine();
    b.setAlign(2);
    b.setFontSize(doubleWidth: true, doubleHeight: true);
    b.setBold(true);
    final totalLabel = 'TOTAL  ';
    final totalVal = Formatters.currency(tx.total);
    // Note: In double size, charsPerLine is effectively halved.
    // However, for right align, the printer handles the margin.
    b.text('$totalLabel$totalVal');

    b.resetStyle();
    b.line('-');

    b.row('Bayar (${tx.paymentMethod})', Formatters.currency(tx.amountPaid));
    b.row('Kembalian', Formatters.currency(tx.changeAmount));
  }

  void buildDebtSummary(Debt d) {
    b.resetStyle();
    b.setAlign(0);

    b.row('Total Piutang Awal', Formatters.currency(d.totalAmount));
    b.row('Total Sudah Bayar', Formatters.currency(d.paidAmount));

    b.emptyLine();
    b.setAlign(2);
    b.setFontSize(doubleWidth: true, doubleHeight: true);
    b.setBold(true);
    b.text('SISA PIUTANG  ${Formatters.currency(d.remainingBalance)}');

    b.resetStyle();
    b.line('-');
  }

  void buildPaymentHistory(List<DebtPayment> payments) {
    b.resetStyle();
    b.setAlign(1);
    b.setBold(true);
    b.text('RIWAYAT CICILAN / PEMBAYARAN');
    b.setBold(false);
    b.emptyLine();

    if (payments.isEmpty) {
      b.text('Belum ada riwayat pembayaran');
    } else {
      for (final p in payments) {
        b.row(Formatters.date(p.createdAt), Formatters.currency(p.amount));
      }
    }
    b.emptyLine();
    b.line('-');
  }

  void buildPaymentInfo(StoreSettings s) {
    if (s.bankAccounts.isEmpty) return;

    b.resetStyle();
    b.setAlign(1);
    b.setBold(true);
    b.text('INFORMASI PEMBAYARAN TRANSFER');
    b.setBold(false);

    for (final acc in s.bankAccounts) {
      b.text('${acc.bankName}: ${acc.accountNumber}');
      b.text('a/n ${acc.accountHolder}');
    }
    b.emptyLine();
  }

  void buildFinalFooter({required bool isDebt}) {
    b.resetStyle();
    b.setAlign(1);
    b.emptyLine();

    if (isDebt) {
      b.text('Dokumen ini adalah bukti sah piutang');
    } else {
      b.text('Terima Kasih atas Kunjungan Anda');
    }

    b.emptyLine();
    b.text('Printed: ${Formatters.dateTime(DateTime.now())}');
  }

  List<String> _wrapText(String text, int width) {
    List<String> lines = [];
    while (text.length > width) {
      int spaceIndex = text.lastIndexOf(' ', width);
      if (spaceIndex == -1) spaceIndex = width;
      lines.add(text.substring(0, spaceIndex).trim());
      text = text.substring(spaceIndex).trim();
    }
    if (text.isNotEmpty) lines.add(text);
    return lines;
  }
}

