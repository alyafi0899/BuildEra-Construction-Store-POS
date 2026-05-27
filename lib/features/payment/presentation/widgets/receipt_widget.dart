// lib/features/payment/presentation/widgets/receipt_widget.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/hive/hive_models.dart';

class ReceiptWidget extends StatelessWidget {
  final HiveTransaction transaction;
  const ReceiptWidget({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final tx = transaction;
    return Container(
      width: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.construction, color: AppColors.primary, size: 28),
        const SizedBox(height: 6),
        Text(AppConstants.storeName,
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 14),
            textAlign: TextAlign.center),
        Text(AppConstants.storeAddress,
            style: const TextStyle(color: Colors.black54, fontSize: 10), textAlign: TextAlign.center),
        Text(AppConstants.storePhone, style: const TextStyle(color: Colors.black54, fontSize: 10)),
        const SizedBox(height: 10),
        _dotted(),
        const SizedBox(height: 8),
        _row('No. Transaksi', tx.transactionCode, mono: true),
        _row('Tanggal', AppFormatters.formatDateTime(tx.transactionDate)),
        _row('Kasir', tx.cashierName),
        _row('Metode', tx.paymentMethod),
        const SizedBox(height: 8),
        _dotted(),
        const SizedBox(height: 8),

        ...tx.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.productName,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 12)),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('  ${AppFormatters.formatQuantity(item.quantity)} ${item.unitName} × ${AppFormatters.formatCurrency(item.pricePerUnit)}',
                  style: const TextStyle(color: Colors.black54, fontSize: 11)),
              Text(AppFormatters.formatCurrency(item.subtotal),
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 11)),
            ]),
          ]),
        )),

        const SizedBox(height: 8),
        _dotted(),
        const SizedBox(height: 8),
        _row('Subtotal', AppFormatters.formatCurrency(tx.subtotal)),
        if (tx.discountAmount > 0)
          _row('Diskon', '- ${AppFormatters.formatCurrency(tx.discountAmount)}', valueColor: Colors.green),
        if (tx.taxAmount > 0)
          _row('PPN 11%', AppFormatters.formatCurrency(tx.taxAmount)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('TOTAL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
          Text(AppFormatters.formatCurrency(tx.totalAmount),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
        const SizedBox(height: 4),
        _row('Bayar', AppFormatters.formatCurrency(tx.paidAmount)),
        _row('Kembali', AppFormatters.formatCurrency(tx.changeAmount), valueColor: Colors.green[700]),
        const SizedBox(height: 10),
        _dotted(),
        const SizedBox(height: 8),
        const Text('Terima kasih atas kepercayaan Anda!\nBarang yang sudah dibeli tidak dapat dikembalikan.',
            style: TextStyle(color: Colors.black54, fontSize: 10), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('*** ${AppConstants.appName} v${AppConstants.appVersion} ***',
            style: const TextStyle(color: Colors.black38, fontSize: 9)),
      ]),
    );
  }

  Widget _row(String label, String value, {Color? valueColor, bool mono = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 11)),
          Text(value, style: TextStyle(
            color: valueColor ?? Colors.black, fontSize: 11, fontWeight: FontWeight.w500,
            fontFamily: mono ? 'monospace' : null)),
        ]),
      );

  Widget _dotted() => Row(
    children: List.generate(40, (_) => const Expanded(
      child: Text('- ', style: TextStyle(color: Colors.black26, fontSize: 8), textAlign: TextAlign.center),
    )),
  );
}
