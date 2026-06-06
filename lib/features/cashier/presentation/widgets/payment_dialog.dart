import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../shared/models/transaction.dart';
import '../../providers/cart_provider.dart';
import '../../../payment/providers/transaction_provider.dart';
import '../../../../core/utils/invoice_helper.dart';
import '../../../settings/providers/settings_provider.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog(
        context:            context,
        barrierDismissible: false,
        builder:            (_) => const PaymentDialog(),
      );

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  String  _method     = AppConstants.paymentCash;
  final   _amountCtrl = TextEditingController();
  final   _notesCtrl  = TextEditingController();
  bool    _processing = false;
  bool    _success    = false;
  Transaction? _tx;

  double get _paid =>
      double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final cart = ref.read(cartProvider);
    if (_method == AppConstants.paymentCash && _paid < cart.total) {
      showError(context, 'Jumlah bayar kurang dari total');
      return;
    }
    setState(() => _processing = true);
    try {
      final txId = await ref.read(transactionsProvider.notifier).checkout(
        paymentMethod: _method,
        amountPaid:    _method == AppConstants.paymentCash ? _paid : cart.total,
        notes:         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      
      // The transaction is now in the list
      final txList = ref.read(transactionsProvider).asData?.value ?? [];
      final tx     = txList.firstWhereOrNull((t) => t.id == txId);
      
      if (tx == null) throw StateError('Transaction not found');

      setState(() { _success = true; _tx = tx; });
    } catch (e) {
      if (mounted) showError(context, 'Gagal memproses: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    return Dialog(
      insetPadding: const EdgeInsets.all(60),
      child: SizedBox(
        width: 640,
        child: _success ? _successPanel(context) : _formPanel(context, cart),
      ),
    );
  }

  // ── Success ───────────────────────────────────────────────────────────────

  Widget _successPanel(BuildContext context) {
    final settings = ref.read(settingsProvider);
    final tx = _tx!;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 70, height: 70,
          decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        Text('Pembayaran Berhasil!', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(tx.invoiceNumber, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, letterSpacing: 1)),
        const SizedBox(height: 32),
        
        // Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionBtn(
              icon: Icons.print_rounded, 
              label: 'Print', 
              onTap: () => InvoiceHelper.printInvoice(tx, settings)
            ),
            const SizedBox(width: 12),
            _ActionBtn(
              icon: Icons.share_rounded, 
              label: 'Share', 
              onTap: () => InvoiceHelper.shareInvoice(tx, settings)
            ),
            const SizedBox(width: 12),
            _ActionBtn(
              icon: Icons.download_rounded, 
              label: 'Simpan', 
              onTap: () => InvoiceHelper.saveInvoice(tx, settings)
            ),
          ],
        ),
        
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.surfaceAlt, foregroundColor: Colors.white),
            child: const Text('TUTUP'),
          ),
        ),
      ]),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _formPanel(BuildContext context, CartState cart) {
    final change = _paid - cart.total;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Header
      _header(context),

      // Body — two columns
      Flexible(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _orderSummary(context, cart)),
            const SizedBox(width: 32),
            Expanded(child: _paymentPanel(context, cart, change)),
          ]),
        ),
      ),

      // Footer
      _footer(context),
    ]);
  }

  Widget _header(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          const Icon(Icons.payment_rounded, color: AppTheme.accent, size: 22),
          const SizedBox(width: 12),
          Text('Pembayaran', style: Theme.of(context).textTheme.headlineMedium),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppTheme.textMuted),
          ),
        ]),
      );

  Widget _orderSummary(BuildContext context, CartState cart) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ringkasan Order',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppTheme.accent)),
      const SizedBox(height: 12),
      ...cart.items.map((i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.product.name,
                        style:    Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis),
                    if (i.isOverridden)
                      const Text('Harga Override', style: TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  '${Formatters.decimal(i.quantity)} × '
                  '${Formatters.currency(i.soldPrice)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(Formatters.currency(i.subtotal),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 13)),
              ]),
            ]),
          )),
      const Divider(color: AppTheme.border, height: 24),
      _row(context, 'Subtotal Item', Formatters.currency(cart.grossSubtotal)),
      if (cart.itemDiscountTotal > 0)
        _row(context, 'Potongan Item', '− ${Formatters.currency(cart.itemDiscountTotal)}',
            color: AppTheme.success),
      if (cart.transDiscountAmount > 0)
        _row(context, 'Diskon Transaksi', '− ${Formatters.currency(cart.transDiscountAmount)}',
            color: AppTheme.success),
      if (cart.taxEnabled)
        _row(context, 'PPN (11%)', Formatters.currency(cart.taxAmount)),
      const SizedBox(height: 8),
      Row(children: [
        Text('TOTAL',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontSize: 18)),
        const Spacer(),
        Text(Formatters.currency(cart.total),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.accent,
                  fontSize: 22,
                )),
      ]),
    ]);
  }

  Widget _paymentPanel(BuildContext context, CartState cart, double change) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Metode Pembayaran',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: AppTheme.accent)),
      const SizedBox(height: 12),
      ...AppConstants.paymentMethods.map((m) => _methodTile(context, m)),
      if (_method == AppConstants.paymentCash) ...[
        const SizedBox(height: 16),
        TextField(
          controller:   _amountCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize:   18,
              fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            labelText:  'Jumlah Bayar',
            prefixText: 'Rp ',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_paid > 0) ...[
          const SizedBox(height: 12),
          // Change display
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (change >= 0 ? AppTheme.success : AppTheme.danger)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: (change >= 0 ? AppTheme.success : AppTheme.danger)
                      .withValues(alpha: 0.4)),
            ),
            child: Row(children: [
              Text('Kembalian',
                  style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                change >= 0
                    ? Formatters.currency(change)
                    : '− ${Formatters.currency(-change)}',
                style: TextStyle(
                  color: change >= 0 ? AppTheme.success : AppTheme.danger,
                  fontSize:   18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
          // Quick cash buttons
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [50000, 100000, 150000, 200000, 500000]
                .where((v) => v >= cart.total)
                .map((v) => OutlinedButton(
                      onPressed: () =>
                          setState(() => _amountCtrl.text = v.toString()),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6)),
                      child: Text(Formatters.currency(v.toDouble()),
                          style: const TextStyle(fontSize: 11)),
                    ))
                .toList(),
          ),
        ],
      ],
      // QRIS / Debit mock panel
      if (_method != AppConstants.paymentCash)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
            padding:     const EdgeInsets.all(20),
            decoration:  BoxDecoration(
              color:        AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border:       Border.all(color: AppTheme.border),
            ),
            child: Column(children: [
              Icon(
                _method == AppConstants.paymentQris
                    ? Icons.qr_code_rounded
                    : Icons.credit_card_rounded,
                size:  72,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(height: 10),
              Text(_method == AppConstants.paymentQris
                  ? 'Scan QR untuk membayar'
                  : 'Tap / Insert kartu debit'),
              const SizedBox(height: 4),
              Text(Formatters.currency(cart.total),
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: AppTheme.accent)),
            ]),
          ),
        ),
    ]);
  }

  Widget _methodTile(BuildContext context, String m) {
    final active = _method == m;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap:        () => setState(() => _method = m),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: active
                ? AppTheme.accent.withValues(alpha: 0.12)
                : AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: active ? AppTheme.accent : AppTheme.border),
          ),
          child: Row(children: [
            Icon(_icon(m),
                color: active ? AppTheme.accent : AppTheme.textSecondary,
                size:  20),
            const SizedBox(width: 12),
            Text(m,
                style: TextStyle(
                  color:      active ? AppTheme.accent : AppTheme.textPrimary,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                )),
            const Spacer(),
            if (active)
              const Icon(Icons.check_circle_rounded,
                  color: AppTheme.accent, size: 18),
          ]),
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border))),
        child: Row(children: [
          OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Batal')),
          const Spacer(),
          SizedBox(
            width:  200,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _processing ? null : _confirm,
              icon: _processing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(_processing ? 'Memproses...' : 'Konfirmasi Bayar'),
            ),
          ),
        ]),
      );

  Widget _row(BuildContext context, String label, String value,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value,
            style: TextStyle(
              color:      color ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            )),
      ]),
    );
  }

  IconData _icon(String m) {
    switch (m) {
      case AppConstants.paymentCash:  return Icons.payments_rounded;
      case AppConstants.paymentQris:  return Icons.qr_code_rounded;
      case AppConstants.paymentDebit: return Icons.credit_card_rounded;
      default:                        return Icons.payment;
    }
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(children: [
          Icon(icon, color: AppTheme.accent, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
