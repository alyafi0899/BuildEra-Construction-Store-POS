import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/purchase_cart_provider.dart';
import '../../../../shared/models/purchase.dart';
import '../../providers/purchase_provider.dart';
import '../../utils/purchase_invoice_helper.dart';
import '../../../settings/providers/settings_provider.dart';

class PurchaseCheckoutDialog extends ConsumerStatefulWidget {
  const PurchaseCheckoutDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PurchaseCheckoutDialog(),
    );
  }

  @override
  ConsumerState<PurchaseCheckoutDialog> createState() => _PurchaseCheckoutDialogState();
}

class _PurchaseCheckoutDialogState extends ConsumerState<PurchaseCheckoutDialog> {
  final _amountPaidCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'Tunai';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final total = ref.read(purchaseCartProvider).total;
    _amountPaidCtrl.text = Formatters.decimal(total);
  }

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final paid = Formatters.parsePrice(_amountPaidCtrl.text);
    
    setState(() => _saving = true);
    try {
      final purchase = await ref.read(purchaseActionProvider.notifier).completePurchase(
        paymentMethod: _paymentMethod,
        amountPaid:    paid,
        notes:         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      
      if (mounted) {
        final settings = ref.read(settingsProvider);
        Navigator.pop(context);
        showSuccess(context, 'Pembelian berhasil dicatat & Stok diupdate');
        
        // Show print option
        await _showPrintPrompt(context, purchase, settings);
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal mencatat pembelian: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showPrintPrompt(BuildContext context, Purchase purchase, dynamic settings) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cetak Nota Pembelian?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih format cetak yang diinginkan:', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            _PrintOptionTile(
              title: 'STRUK THERMAL (KASIR)',
              subtitle: 'Ukuran 58mm/80mm untuk gudang',
              icon: Icons.receipt_long_rounded,
              color: AppTheme.accent,
              onTap: () {
                Navigator.pop(context);
                PurchaseInvoiceHelper.printInvoice(purchase, settings);
              },
            ),
            const SizedBox(height: 12),
            _PrintOptionTile(
              title: 'NOTA PEMBELIAN (A4)',
              subtitle: 'Dokumen PDF resmi untuk arsip',
              icon: Icons.picture_as_pdf_rounded,
              color: AppTheme.info,
              onTap: () {
                Navigator.pop(context);
                PurchaseInvoiceHelper.printInvoiceA4(purchase, settings);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('TUTUP', style: TextStyle(color: AppTheme.textMuted))
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(purchaseCartProvider);
    final paid = Formatters.parsePrice(_amountPaidCtrl.text);
    final remaining = cart.total - paid;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Selesaikan Pembelian', 
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Text('Supplier: ${cart.supplierName ?? "Umum"}', 
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const Divider(height: 40),

            Row(
              children: [
                const Text('Total Tagihan:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text(Formatters.currency(cart.total), 
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.accent)),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                _PayMethodChip(
                  label: 'Tunai', 
                  icon: Icons.money_rounded,
                  selected: _paymentMethod == 'Tunai',
                  onTap: () => setState(() => _paymentMethod = 'Tunai'),
                ),
                const SizedBox(width: 12),
                _PayMethodChip(
                  label: 'Transfer', 
                  icon: Icons.account_balance_rounded,
                  selected: _paymentMethod == 'Transfer',
                  onTap: () => setState(() => _paymentMethod = 'Transfer'),
                ),
                const SizedBox(width: 12),
                _PayMethodChip(
                  label: 'Hutang', 
                  icon: Icons.timer_rounded,
                  selected: _paymentMethod == 'Hutang',
                  onTap: () => setState(() => _paymentMethod = 'Hutang'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _amountPaidCtrl,
              decoration: const InputDecoration(
                labelText: 'Jumlah Bayar (Rp)',
                prefixText: 'Rp ',
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              onChanged: (_) => setState(() {}),
            ),
            
            if (remaining > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Sisa ${Formatters.currency(remaining)} akan dicatat sebagai hutang.', 
                        style: const TextStyle(color: AppTheme.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Catatan Pembelian (Opsional)',
                hintText: 'Misal: Nota #12345',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('BATAL'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _complete,
                    child: _saving 
                      ? const AppLoading()
                      : const Text('KONFIRMASI'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrintOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PrintOptionTile({
    required this.title, 
    required this.subtitle, 
    required this.icon, 
    required this.color, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withValues(alpha: 0.3)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _PayMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PayMethodChip({
    required this.label, 
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? AppTheme.accent : AppTheme.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(icon, color: selected ? AppTheme.accent : AppTheme.textMuted, size: 24),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(
                  fontSize: 12, 
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? AppTheme.accent : AppTheme.textSecondary,
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
