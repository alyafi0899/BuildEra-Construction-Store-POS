// lib/features/payment/presentation/pages/payment_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../cashier/presentation/providers/cart_provider.dart';
import '../providers/transaction_provider.dart';

class PaymentDialog extends ConsumerStatefulWidget {
  const PaymentDialog({super.key});

  @override
  ConsumerState<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<PaymentDialog> {
  String _selectedMethod = AppConstants.paymentMethods.first;
  final _cashCtrl = TextEditingController();
  bool _processing = false;

  double get _total => ref.read(cartProvider).total;
  double get _paid => double.tryParse(_cashCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  double get _change => _paid - _total;
  bool get _isValid => _selectedMethod != 'Tunai' || _paid >= _total;

  @override
  void initState() {
    super.initState();
    _cashCtrl.text = _total.toInt().toString();
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    return Dialog(
      child: SizedBox(
        width: 550,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.payment_rounded, color: AppColors.primary, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Text('Proses Pembayaran',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order summary
                    Text('Ringkasan Pesanan',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          ...cart.items.map((item) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${item.productName} (${AppFormatters.formatQuantity(item.quantity)} ${item.unitName})',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      AppFormatters.formatCurrency(item.subtotal),
                                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 13),
                                    ),
                                  ],
                                ),
                              )),
                          const Divider(color: AppColors.border),
                          _summaryRow('Subtotal', AppFormatters.formatCurrency(cart.subtotal)),
                          if (cart.discountAmount > 0)
                            _summaryRow(
                              'Diskon (${cart.discountPercent.toStringAsFixed(0)}%)',
                              '- ${AppFormatters.formatCurrency(cart.discountAmount)}',
                              valueColor: AppColors.success,
                            ),
                          if (cart.taxEnabled)
                            _summaryRow('PPN 11%', AppFormatters.formatCurrency(cart.taxAmount)),
                          const Divider(color: AppColors.border),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL',
                                  style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              Text(
                                AppFormatters.formatCurrency(cart.total),
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Payment method
                    Text('Metode Pembayaran',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            )),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: AppConstants.paymentMethods
                          .map((method) => _PaymentMethodChip(
                                label: method,
                                icon: _methodIcon(method),
                                isSelected: _selectedMethod == method,
                                onTap: () => setState(() => _selectedMethod = method),
                              ))
                          .toList(),
                    ),

                    // Cash input
                    if (_selectedMethod == 'Tunai') ...[
                      const SizedBox(height: 20),
                      Text('Jumlah Bayar',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              )),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _cashCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 22),
                        decoration: const InputDecoration(
                          prefixText: 'Rp ',
                          prefixStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      // Quick cash buttons
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickAmounts(cart.total).map((amount) {
                          return OutlinedButton(
                            onPressed: () {
                              _cashCtrl.text = amount.toInt().toString();
                              setState(() {});
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              side: const BorderSide(color: AppColors.border),
                              foregroundColor: AppColors.textSecondary,
                            ),
                            child: Text(AppFormatters.formatCurrency(amount.toDouble()), style: const TextStyle(fontSize: 12)),
                          );
                        }).toList(),
                      ),
                      if (_paid > 0 && _paid >= _total) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.successContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Kembalian',
                                  style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15)),
                              Text(
                                AppFormatters.formatCurrency(_change),
                                style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 20),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_paid > 0 && _paid < _total) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_rounded, color: AppColors.error, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Kurang ${AppFormatters.formatCurrency(_total - _paid)}',
                                style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    // Non-cash info
                    if (_selectedMethod != 'Tunai') ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_rounded, color: AppColors.info, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Pembayaran via $_selectedMethod',
                              style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: (_processing || !_isValid) ? null : _processPayment,
                    icon: _processing
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _processing ? 'Memproses...' : 'Konfirmasi Pembayaran',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 13)),
        ],
      ),
    );
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'Tunai': return Icons.payments_rounded;
      case 'Debit/Kredit': return Icons.credit_card_rounded;
      case 'QRIS': return Icons.qr_code_rounded;
      case 'Transfer Bank': return Icons.account_balance_rounded;
      default: return Icons.payment_rounded;
    }
  }

  List<int> _quickAmounts(double total) {
    final totalInt = total.ceil();
    final amounts = {
      _roundUp(totalInt, 1000),
      _roundUp(totalInt, 5000),
      _roundUp(totalInt, 10000),
      _roundUp(totalInt, 50000),
      _roundUp(totalInt, 100000),
    };
    return amounts.where((a) => a >= total).take(4).toList();
  }

  int _roundUp(int value, int multiple) {
    return ((value + multiple - 1) ~/ multiple) * multiple;
  }

  Future<void> _processPayment() async {
    setState(() => _processing = true);

    final cart = ref.read(cartProvider);
    final paidAmount = _selectedMethod == 'Tunai'
        ? _paid
        : cart.total;

    final result = await ref.read(transactionListProvider.notifier).processPayment(
      cart: cart,
      paymentMethod: _selectedMethod,
      paidAmount: paidAmount,
    );

    setState(() => _processing = false);

    if (mounted) {
      Navigator.pop(context);
      if (result.success) {
        showSuccessSnackbar(context, 'Transaksi ${result.transactionCode} berhasil!');
        _showReceiptDialog(result.transactionCode!, paidAmount, cart.total);
      } else {
        showErrorSnackbar(context, result.error ?? 'Gagal memproses pembayaran');
      }
    }
  }

  void _showReceiptDialog(String code, double paid, double total) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.successContainer,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 32),
            ),
            const SizedBox(height: 12),
            const Text('Pembayaran Berhasil!',
                style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            if (_selectedMethod == 'Tunai') ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dibayar', style: TextStyle(color: AppColors.textSecondary)),
                  Text(AppFormatters.formatCurrency(paid), style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembalian', style: TextStyle(color: AppColors.textSecondary)),
                  Text(
                    AppFormatters.formatCurrency(paid - total),
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
