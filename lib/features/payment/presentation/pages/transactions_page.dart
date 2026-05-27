// lib/features/payment/presentation/pages/transactions_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/hive/hive_models.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../providers/transaction_provider.dart';

class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySales = ref.watch(todaySalesProvider);
    final todayCount = ref.watch(todayTransactionCountProvider);
    final txList = ref.watch(transactionListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const Text('Riwayat Transaksi',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        ),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(children: [
            Expanded(child: StatCard(
              title: 'Penjualan Hari Ini',
              value: AppFormatters.formatCurrency(todaySales),
              icon: Icons.trending_up_rounded, iconColor: AppColors.success,
              subtitle: 'Total omzet hari ini',
            )),
            const SizedBox(width: 12),
            Expanded(child: StatCard(
              title: 'Transaksi Hari Ini',
              value: '$todayCount transaksi',
              icon: Icons.receipt_rounded, iconColor: AppColors.info,
              subtitle: AppFormatters.formatDate(DateTime.now()),
            )),
            const SizedBox(width: 12),
            Expanded(child: StatCard(
              title: 'Total Semua Transaksi',
              value: AppFormatters.formatCurrency(txList.fold(0.0, (s, t) => s + t.totalAmount)),
              icon: Icons.account_balance_wallet_rounded, iconColor: AppColors.primary,
              subtitle: '${txList.length} transaksi tersimpan',
            )),
          ]),
        ),

        Expanded(
          child: txList.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum ada transaksi',
                  subtitle: 'Transaksi akan muncul setelah pembayaran selesai',
                )
              : Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(children: [
                          Expanded(flex: 3, child: _H('Kode Transaksi')),
                          Expanded(flex: 2, child: _H('Waktu')),
                          Expanded(flex: 2, child: _H('Metode')),
                          Expanded(flex: 2, child: _H('Total')),
                          Expanded(flex: 2, child: _H('Dibayar')),
                          Expanded(flex: 2, child: _H('Kembalian')),
                          Expanded(flex: 1, child: _H('Status')),
                          SizedBox(width: 50),
                        ]),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: txList.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                          itemBuilder: (ctx, i) => _TxRow(tx: txList[i])
                              .animate(delay: Duration(milliseconds: 20 * i)).fadeIn(duration: 200.ms),
                        ),
                      ),
                    ]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5));
}

class _TxRow extends StatefulWidget {
  final HiveTransaction tx;
  const _TxRow({required this.tx});
  @override State<_TxRow> createState() => _TxRowState();
}

class _TxRowState extends State<_TxRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final tx = widget.tx;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_)  => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _hovering ? AppColors.surfaceVariant.withValues(alpha: 0.5) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Expanded(flex: 3, child: Text(tx.transactionCode,
              style: const TextStyle(color: AppColors.primary, fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 12))),
          Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppFormatters.formatDate(tx.transactionDate),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
            Text(AppFormatters.formatTime(tx.transactionDate),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ])),
          Expanded(flex: 2, child: Row(children: [
            Icon(_icon(tx.paymentMethod), size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(tx.paymentMethod, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ])),
          Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(tx.totalAmount),
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
          Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(tx.paidAmount),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))),
          Expanded(flex: 2, child: Text(AppFormatters.formatCurrency(tx.changeAmount),
              style: const TextStyle(color: AppColors.success, fontSize: 12))),
          Expanded(flex: 1, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: AppColors.successContainer, borderRadius: BorderRadius.circular(4)),
            child: const Text('Selesai', style: TextStyle(color: AppColors.success, fontSize: 10, fontWeight: FontWeight.w600)),
          )),
          SizedBox(width: 50, child: IconButton(
            onPressed: () => showDialog(context: context, builder: (_) => _DetailDialog(tx: tx)),
            icon: const Icon(Icons.visibility_rounded, size: 16),
            color: AppColors.textSecondary, tooltip: 'Detail', visualDensity: VisualDensity.compact,
          )),
        ]),
      ),
    );
  }

  IconData _icon(String method) {
    switch (method) {
      case 'Tunai': return Icons.payments_rounded;
      case 'Debit/Kredit': return Icons.credit_card_rounded;
      case 'QRIS': return Icons.qr_code_rounded;
      default: return Icons.payment_rounded;
    }
  }
}

class _DetailDialog extends StatelessWidget {
  final HiveTransaction tx;
  const _DetailDialog({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 480,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
            child: Row(children: [
              const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text('Detail Transaksi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary)),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tx.transactionCode,
                        style: const TextStyle(fontFamily: 'monospace', color: AppColors.primary, fontWeight: FontWeight.w700)),
                    Text(AppFormatters.formatDateTime(tx.transactionDate),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.successContainer, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Selesai', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                ]),
                const SizedBox(height: 16),
                const Divider(color: AppColors.border),
                const SizedBox(height: 8),

                ...tx.items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.productName,
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('${AppFormatters.formatQuantity(item.quantity)} ${item.unitName} × ${AppFormatters.formatCurrency(item.pricePerUnit)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ])),
                    Text(AppFormatters.formatCurrency(item.subtotal),
                        style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                )),

                const SizedBox(height: 8),
                const Divider(color: AppColors.border),
                _row('Subtotal', AppFormatters.formatCurrency(tx.subtotal)),
                if (tx.discountAmount > 0)
                  _row('Diskon', '- ${AppFormatters.formatCurrency(tx.discountAmount)}', color: AppColors.success),
                if (tx.taxAmount > 0)
                  _row('PPN 11%', AppFormatters.formatCurrency(tx.taxAmount)),
                const Divider(color: AppColors.border),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('TOTAL', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(AppFormatters.formatCurrency(tx.totalAmount),
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 18)),
                ]),
                const SizedBox(height: 8),
                _row('Metode', tx.paymentMethod),
                _row('Dibayar', AppFormatters.formatCurrency(tx.paidAmount)),
                _row('Kembalian', AppFormatters.formatCurrency(tx.changeAmount), color: AppColors.success),
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup')),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
      Text(value, style: TextStyle(color: color ?? AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
    ]),
  );
}
