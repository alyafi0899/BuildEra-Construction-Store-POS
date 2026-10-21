import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/models/purchase.dart';
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
      final purchase = receipt.metadata['purchase'] as Purchase?;
      final customer = receipt.metadata['customer'] as Customer?;
      final payments = receipt.metadata['payments'] as List<DebtPayment>?;
      final logoBytes = receipt.metadata['logoBytes'] as Uint8List?;
      final qrisBytes = receipt.metadata['qrisBytes'] as Uint8List?;

      if (settings == null) throw 'Store settings missing from metadata';

      // 1. HEADER
      sectionBuilder.buildHeader(settings, logoBytes: logoBytes);

      // 2. INFORMATION SECTION
      if (debt != null) sectionBuilder.buildDebtTitle();
      if (debt != null && customer != null) {
        sectionBuilder.buildDebtInfo(customer, debt);
        if (tx?.cashierName?.isNotEmpty ?? false) {
          sectionBuilder.buildDebtCashier(tx!.cashierName!);
        }
      } else if (purchase != null) {
        sectionBuilder.buildPurchaseInfo(purchase);
      } else if (tx != null) {
        sectionBuilder.buildTransactionInfo(tx);
      }

      // 3. ITEM SECTION
      if (tx != null) {
        sectionBuilder.buildItems(tx.items);
      } else if (purchase != null) {
        sectionBuilder.buildPurchaseItems(purchase.items);
      }

      // 4. SUMMARY SECTION
      if (debt != null) {
        sectionBuilder.buildDebtSummary(debt, tx: tx);
      } else if (purchase != null) {
        sectionBuilder.buildPurchaseSummary(purchase);
      } else if (tx != null) {
        sectionBuilder.buildTransactionSummary(tx);
      }

      // 4.1 NOTES
      if ((tx?.notes?.isNotEmpty ?? false) ||
          (debt?.notes?.isNotEmpty ?? false) ||
          (purchase?.notes?.isNotEmpty ?? false)) {
        sectionBuilder
            .buildNotes(tx?.notes ?? debt?.notes ?? purchase?.notes ?? '');
      }

      // 5. PAYMENT HISTORY (For Debt)
      if (payments != null && payments.isNotEmpty) {
        sectionBuilder.buildPaymentHistory(payments);
      }

      // 6. CONDITIONAL PAYMENT INFO
      final isTransferOrDebit =
          tx?.paymentMethod == AppConstants.paymentTransfer ||
              tx?.paymentMethod == AppConstants.paymentDebit;
      final isQris = tx?.paymentMethod.trim().toLowerCase() ==
          AppConstants.paymentQris.toLowerCase();
      if (kDebugMode && (isQris || debt != null)) {
        debugPrint(
          'ESC/POS QRIS section: payment method matched=$isQris, '
          'image available=${qrisBytes != null}',
        );
      }
      if (debt != null || isTransferOrDebit) {
        sectionBuilder.buildPaymentInfo(settings);
      }

      // 6.1 QRIS IMAGE
      if (debt != null || isQris) {
        sectionBuilder.buildQris(qrisBytes);
      }

      // 7. FINAL FOOTER
      sectionBuilder.buildFinalFooter(isDebt: debt != null);

      final bytes = builder.build(
        cut: profile.defaults['autoCut'] != false,
      );

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
  final int maxWidthDots;
  int _alignment = 0;

  EscPosBuilder(double widthMm)
      : charsPerLine = widthMm <= 60 ? 32 : 48,
        maxWidthDots = widthMm <= 60 ? 384 : 576 {
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
    _alignment = align;
    _bytes.addAll([0x1B, 0x61, align]);
  }

  bool imageRaster(
    Uint8List imageBytes, {
    required int maxWidthDots,
    int? maxHeightDots,
    bool dither = false,
    int marginDots = 0,
    bool allowUpscale = false,
  }) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null || maxWidthDots < 8 || marginDots < 0) return false;

      final printerWidth =
          this.maxWidthDots < maxWidthDots ? this.maxWidthDots : maxWidthDots;
      final rowWidthDots = (printerWidth ~/ 8) * 8;
      final contentWidthLimit = rowWidthDots - marginDots * 2;
      final contentHeightLimit =
          (maxHeightDots ?? decoded.height + marginDots * 2) - marginDots * 2;
      if (contentWidthLimit < 1 || contentHeightLimit < 1) return false;

      final scaleLimits = [
        contentWidthLimit / decoded.width,
        contentHeightLimit / decoded.height,
      ];
      if (!allowUpscale) scaleLimits.add(1.0);
      final scale = scaleLimits.reduce((a, b) => a < b ? a : b);
      final contentWidth =
          (decoded.width * scale).floor().clamp(1, contentWidthLimit);
      final contentHeight =
          (decoded.height * scale).floor().clamp(1, contentHeightLimit);
      final resized = img.copyResize(
        decoded,
        width: contentWidth,
        height: contentHeight,
        interpolation: allowUpscale && !dither
            ? img.Interpolation.nearest
            : img.Interpolation.average,
      );

      final grayscale = List<double>.filled(contentWidth * contentHeight, 255);
      for (var y = 0; y < contentHeight; y++) {
        for (var x = 0; x < contentWidth; x++) {
          final pixel = resized.getPixel(x, y);
          final alpha = pixel.a.toDouble() / 255;
          final red = pixel.r.toDouble() * alpha + 255 * (1 - alpha);
          final green = pixel.g.toDouble() * alpha + 255 * (1 - alpha);
          final blue = pixel.b.toDouble() * alpha + 255 * (1 - alpha);
          grayscale[y * contentWidth + x] =
              red * 0.299 + green * 0.587 + blue * 0.114;
        }
      }

      final rasterHeight = contentHeight + marginDots * 2;
      final bytesPerRow = (contentWidth + marginDots * 2 + 7) ~/ 8;
      final rasterWidthDots = bytesPerRow * 8;
      if (rasterWidthDots > rowWidthDots ||
          (maxHeightDots != null && rasterHeight > maxHeightDots)) {
        return false;
      }
      final rasterData = List<int>.filled(bytesPerRow * rasterHeight, 0);
      final left = (rasterWidthDots - contentWidth) ~/ 2;

      for (var y = 0; y < contentHeight; y++) {
        for (var x = 0; x < contentWidth; x++) {
          final index = y * contentWidth + x;
          final oldValue = grayscale[index];
          final black = oldValue < 128;
          if (black) {
            final rasterX = left + x;
            final rasterY = marginDots + y;
            rasterData[rasterY * bytesPerRow + rasterX ~/ 8] |=
                0x80 >> (rasterX % 8);
          }
          if (dither) {
            final error = oldValue - (black ? 0 : 255);
            if (x + 1 < contentWidth) {
              grayscale[index + 1] += error * 7 / 16;
            }
            if (y + 1 < contentHeight) {
              if (x > 0) grayscale[index + contentWidth - 1] += error * 3 / 16;
              grayscale[index + contentWidth] += error * 5 / 16;
              if (x + 1 < contentWidth) {
                grayscale[index + contentWidth + 1] += error / 16;
              }
            }
          }
        }
      }

      final previousAlignment = _alignment;
      setAlign(1);
      _bytes.addAll([
        0x1D,
        0x76,
        0x30,
        0x00,
        bytesPerRow & 0xFF,
        (bytesPerRow >> 8) & 0xFF,
        rasterHeight & 0xFF,
        (rasterHeight >> 8) & 0xFF,
        ...rasterData,
      ]);
      setAlign(previousAlignment);
      return true;
    } catch (_) {
      return false;
    }
  }

  void text(String text, {bool newline = true}) {
    _bytes.addAll(ascii.encode(sanitizeForPrinter(text)));
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

  Uint8List build({bool cut = true}) {
    final feedLines = cut ? 3 : 5;
    for (var i = 0; i < feedLines; i++) {
      emptyLine();
    }
    if (cut) this.cut();
    return Uint8List.fromList(_bytes);
  }

  /// Splits a text into two parts (left and right aligned)
  void row(String left, String right) {
    left = sanitizeForPrinter(left);
    right = sanitizeForPrinter(right);
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

  void buildHeader(StoreSettings s, {Uint8List? logoBytes}) {
    b.setAlign(1);
    if (logoBytes != null) {
      b.imageRaster(
        logoBytes,
        maxWidthDots: b.maxWidthDots,
        maxHeightDots: 120,
        dither: true,
      );
    }
    b.setFontSize(doubleWidth: true, doubleHeight: true);
    // b.setBold(true); // Removed bold
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
    final customerName = tx.customerName?.trim() ?? '';
    if (customerName.isNotEmpty) {
      final customerLines = _wrapText(
        customerName,
        b.charsPerLine - 'Plg   : '.length,
      );
      b.text('Plg   : ${customerLines.first}');
      for (final line in customerLines.skip(1)) {
        b.text(line);
      }
    }

    b.emptyLine();
    b.line('-');
  }

  void buildDebtTitle() {
    b.resetStyle();
    b.setAlign(1);
    b.setBold(true);
    b.text('STRUK TAGIHAN');
    b.setBold(false);
  }

  void buildDebtCashier(String cashierName) {
    b.setAlign(0);
    b.text('Kasir: $cashierName');
  }

  void buildPurchaseInfo(Purchase p) {
    b.resetStyle();
    b.setAlign(1);
    b.text('NOTA MASUK (PEMBELIAN)', newline: true);
    b.setAlign(0);

    final dateStr = Formatters.date(p.createdAt);
    final timeStr = DateFormat('HH:mm').format(p.createdAt);

    b.row('Staff : ${p.staffName ?? 'Admin'}', dateStr);
    b.row('Supp  : ${p.supplierName ?? 'Umum'}', timeStr);
    b.row('No    : ${p.invoiceNumber}', '');

    b.emptyLine();
    b.line('-');
  }

  void buildDebtInfo(Customer c, Debt d) {
    b.resetStyle();
    b.setAlign(0);

    final dateStr = Formatters.date(d.createdAt);
    final timeStr = DateFormat('HH:mm').format(d.createdAt);

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
      final qtyStr =
          '${Formatters.decimal(item.quantity)} ${item.unitName} x ${Formatters.currency(item.soldPrice)}';
      final subtotalStr = Formatters.currency(item.subtotal);
      b.row(qtyStr, subtotalStr);

      if (item.totalDiscount > 0) {
        b.setAlign(2);
        b.text('(Disc: -${Formatters.currency(item.totalDiscount)})');
        b.setAlign(0);
      }

      b.emptyLine();
    }
    b.line('-');
  }

  void buildPurchaseItems(List<PurchaseItem> items) {
    b.resetStyle();
    for (final item in items) {
      final nameLines = _wrapText(item.productName, b.charsPerLine);
      for (final nLine in nameLines) {
        b.text(nLine);
      }

      final qtyStr =
          '${Formatters.decimal(item.quantity)} ${item.unitName} x ${Formatters.currency(item.purchasePrice)}';
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
      b.row('Pajak (PPN)', Formatters.currency(tx.taxAmount));
    }

    if (tx.shippingFee > 0) {
      b.row('Ongkir', Formatters.currency(tx.shippingFee));
    }

    // TOTAL
    b.emptyLine();
    b.setAlign(2);
    // b.setFontSize(doubleWidth: true, doubleHeight: true); // Removed stretch
    // b.setBold(true); // Removed bold
    final totalVal = Formatters.currency(tx.total);
    b.text('TOTAL  $totalVal');

    b.resetStyle();
    b.line('-');

    b.row('Bayar (${tx.paymentMethod})', Formatters.currency(tx.amountPaid));
    b.row('Kembalian', Formatters.currency(tx.changeAmount));
  }

  void buildPurchaseSummary(Purchase p) {
    b.resetStyle();
    b.setAlign(0);

    b.row('Subtotal', Formatters.currency(p.subtotal));
    if (p.shippingFee > 0) {
      b.row('Biaya Kirim', Formatters.currency(p.shippingFee));
    }

    b.emptyLine();
    b.setAlign(2);
    final totalVal = Formatters.currency(p.total);
    b.text('TOTAL  $totalVal');

    b.resetStyle();
    b.line('-');

    b.row('Bayar (${p.paymentMethod})', Formatters.currency(p.amountPaid));
    if (p.total > p.amountPaid) {
      b.row('Sisa Hutang', Formatters.currency(p.total - p.amountPaid));
    }
  }

  void buildDebtSummary(Debt d, {Transaction? tx}) {
    b.resetStyle();
    b.setAlign(0);

    b.row('Total Piutang Awal', Formatters.currency(d.totalAmount));
    if (tx != null && tx.shippingFee > 0) {
      b.row('Termasuk Ongkir', Formatters.currency(tx.shippingFee));
    }
    b.row('Total Sudah Bayar', Formatters.currency(d.paidAmount));

    b.emptyLine();
    b.setAlign(2);
    // b.setFontSize(doubleWidth: true, doubleHeight: true); // Removed stretch
    // b.setBold(true); // Removed bold
    b.text('SISA PIUTANG  ${Formatters.currency(d.remainingBalance)}');

    b.resetStyle();
    b.line('-');
  }

  void buildPaymentHistory(List<DebtPayment> payments) {
    b.resetStyle();
    b.setAlign(1);
    // b.setBold(true); // Removed bold
    b.text('RIWAYAT CICILAN / PEMBAYARAN');
    // b.setBold(false);
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

  void buildNotes(String notes) {
    b.resetStyle();
    b.setAlign(0);
    // b.setBold(true); // Removed bold
    b.text('Keterangan:');
    // b.setBold(false);
    final lines = _wrapText(notes, b.charsPerLine);
    for (final l in lines) {
      b.text(l);
    }
    b.emptyLine();
    b.line('-');
  }

  void buildPaymentInfo(StoreSettings s) {
    if (s.bankAccounts.isEmpty) return;

    b.resetStyle();
    if (s.bankAccounts.isNotEmpty) {
      b.setAlign(1);
      // b.setBold(true); // Removed bold
      b.text('INFORMASI PEMBAYARAN TRANSFER');
      // b.setBold(false);

      for (final acc in s.bankAccounts) {
        b.text('${acc.bankName}: ${acc.accountNumber}');
        b.text('a/n ${acc.accountHolder}');
      }
      b.emptyLine();
    }
  }

  void buildQris(Uint8List? qrisBytes) {
    if (qrisBytes == null) return;
    b.resetStyle();
    b.setAlign(1);
    b.text('Scan QRIS untuk membayar');
    final rasterAdded = b.imageRaster(
      qrisBytes,
      maxWidthDots: b.maxWidthDots,
      maxHeightDots: 288,
      marginDots: 8,
      allowUpscale: true,
    );
    if (kDebugMode) {
      debugPrint('ESC/POS QRIS raster added: $rasterAdded');
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
    b.text('Waktu Cetak: ${Formatters.dateTime(DateTime.now())}');
  }

  List<String> _wrapText(String text, int width) {
    text = sanitizeForPrinter(text);
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

String sanitizeForPrinter(String input) {
  const replacements = {
    '–': '-',
    '—': '-',
    '‘': "'",
    '’': "'",
    '“': '"',
    '”': '"',
    '•': '*',
    '…': '...',
    '×': 'x',
    '\u00A0': ' ',
    '\t': ' ',
  };
  final replaced = input.replaceAllMapped(
    RegExp('[${replacements.keys.map(RegExp.escape).join()}]'),
    (match) => replacements[match[0]]!,
  );
  return String.fromCharCodes(
    replaced.runes.map((rune) => rune >= 0x20 && rune <= 0x7E ? rune : 0x3F),
  );
}
