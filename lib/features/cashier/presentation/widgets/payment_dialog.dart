import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/core/utils/formatters.dart';
import 'package:buildera/shared/widgets/common_widgets.dart';
import 'package:buildera/features/cashier/providers/cart_provider.dart';
import 'package:buildera/features/payment/providers/transaction_provider.dart';
import 'package:buildera/shared/models/transaction.dart';
import 'package:buildera/core/constants/app_constants.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PaymentDialog(),
    );
  }

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  final _amountCtrl = TextEditingController();
  String _method = 'Tunai';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final cart = ref.read(cartProvider);
    _amountCtrl.text = cart.total.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    final cart = ref.read(cartProvider);
    final amountPaid = double.tryParse(_amountCtrl.text) ?? 0;

    if (amountPaid < cart.total && _method != AppConstants.paymentPiutang) {
      showError(context, 'Pembayaran kurang dari total belanja');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final txId = await ref.read(transactionsProvider.notifier).checkout(
        paymentMethod: _method,
        amountPaid: amountPaid,
      );

      if (mounted) {
        final tx = await ref.read(transactionByIdProvider(txId).future);
        Navigator.pop(context);
        if (tx != null) _showSuccessDialog(tx);
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal memproses pembayaran: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessDialog(Transaction tx) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text('Pembayaran Berhasil!', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(tx.invoiceNumber, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('Cetak Nota'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.payment_rounded, color: colorScheme.primary, size: 22),
              const SizedBox(width: 12),
              Text('Penyelesaian Pembayaran', style: Theme.of(context).textTheme.headlineMedium),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ]),
            const Divider(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(children: [
                _summaryRow('Subtotal', cart.grossSubtotal),
                if (cart.totalDiscount > 0)
                  _summaryRow('Total Diskon', -cart.totalDiscount, color: const Color(0xFF2ECC71)),
                if (cart.taxEnabled)
                  _summaryRow('PPN (11%)', cart.taxAmount),
                const Divider(height: 24),
                _summaryRow('TOTAL', cart.total, isBold: true),
              ]),
            ),
            const SizedBox(height: 24),
            Text('Metode Pembayaran', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(children: [
              _methodTile('Tunai', Icons.money_rounded),
              const SizedBox(width: 12),
              _methodTile('QRIS', Icons.qr_code_scanner_rounded),
              const SizedBox(width: 12),
              _methodTile(AppConstants.paymentPiutang, Icons.history_edu_rounded),
            ]),
            const SizedBox(height: 24),
            Text('Jumlah Bayar (Rp)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.backspace_outlined),
                  onPressed: () => _amountCtrl.clear(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayment,
                child: _isProcessing 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('PROSES PEMBAYARAN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Text(label, style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: isBold ? 16 : 14,
        )),
        const Spacer(),
        Text(Formatters.currency(value), style: TextStyle(
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: isBold ? 18 : 14,
          color: color,
        )),
      ]),
    );
  }

  Widget _methodTile(String m, IconData icon) {
    final isSelected = _method == m;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _method = m),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primary.withValues(alpha: 0.1) : colorScheme.surface,
            border: Border.all(
              color: isSelected ? colorScheme.primary : colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(icon, color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(m, style: TextStyle(
              color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            )),
          ]),
        ),
      ),
    );
  }
}
