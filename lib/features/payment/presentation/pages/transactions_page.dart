import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/utils/invoice_helper.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../../debts/providers/debt_repository.dart';
import '../../../debts/models/debt.dart';
import '../../../../core/constants/app_constants.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  Transaction? _selected;
  final ScrollController _listScrollController = ScrollController();

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // List Section
          Expanded(
            flex: 6,
            child: Column(
              children: [
                PageHeader(
                  title: 'Riwayat Transaksi',
                  subtitle: 'Semua transaksi yang telah selesai',
                  icon: Icons.receipt_long_rounded,
                  actions: [
                    IconButton(
                      onPressed: () => ref.read(transactionsProvider.notifier).refresh(),
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
                    ),
                  ],
                ),
                Expanded(
                  child: txAsync.when(
                    loading: () => const AppLoading(),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (txs) {
                      if (txs.isEmpty) {
                        return const EmptyState(
                          icon: Icons.receipt_long_outlined,
                          title: 'Belum ada transaksi',
                          subtitle: 'Transaksi akan muncul di sini setelah pembayaran selesai',
                        );
                      }
                      return Scrollbar(
                        controller: _listScrollController,
                        thumbVisibility: true,
                        child: ListView.separated(
                          controller: _listScrollController,
                          padding: const EdgeInsets.all(20),
                          itemCount: txs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final tx = txs[i];
                            return _TxCard(
                              key: ValueKey('tx_card_${tx.id}'),
                              tx: tx,
                              selected: _selected?.id == tx.id,
                              onTap: () {
                                setState(() {
                                  _selected = _selected?.id == tx.id ? null : tx;
                                });
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Detail Section
          if (_selected != null)
            SizedBox(
              width: 450,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(left: BorderSide(color: AppTheme.border, width: 1)),
                ),
                child: _TxDetail(
                  key: ValueKey('tx_detail_view_${_selected!.id}'),
                  tx: _selected!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TxCard extends ConsumerWidget {
  final Transaction tx;
  final bool        selected;
  final VoidCallback onTap;
  const _TxCard({super.key, required this.tx, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDebt = tx.paymentMethod == AppConstants.paymentPiutang;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        selected ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.card,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: selected ? AppTheme.accent : AppTheme.border),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: AppTheme.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tx.invoiceNumber,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontFamily: 'monospace', fontSize: 13)),
            Text(Formatters.dateTime(tx.createdAt), style: Theme.of(context).textTheme.bodySmall),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Formatters.currency(tx.total),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.accent)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDebt)
                  _DebtStatusBadge(tx: tx),
                const SizedBox(width: 4),
                StatusChip(label: tx.paymentMethod, color: _methodColor(tx.paymentMethod)),
              ],
            ),
          ]),
        ]),
      ),
    );
  }

  Color _methodColor(String m) {
    switch (m) {
      case 'Tunai':  return AppTheme.success;
      case 'QRIS':   return AppTheme.info;
      case 'Debit':  return AppTheme.accent;
      default:       return AppTheme.textSecondary;
    }
  }
}

class _DebtStatusBadge extends ConsumerWidget {
  final Transaction tx;
  const _DebtStatusBadge({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tx.customerId == null) return const SizedBox();
    
    // Using a more stable watch strategy
    final debtsAsync = ref.watch(debtsProvider(tx.customerId!));
    
    return debtsAsync.maybeWhen(
      data: (debts) {
        final d = debts.where((d) => d.transactionId == tx.id).firstOrNull;
        if (d == null) return const SizedBox();
        final isPaid = d.status == DebtStatus.paid;
        return StatusChip(
          label: isPaid ? 'LUNAS' : 'BELUM LUNAS',
          color: isPaid ? AppTheme.success : AppTheme.danger,
        );
      },
      orElse: () => const SizedBox(width: 60, height: 20),
    );
  }
}

class _TxDetail extends StatefulWidget {
  final Transaction tx;
  const _TxDetail({super.key, required this.tx});

  @override
  State<_TxDetail> createState() => _TxDetailState();
}

class _TxDetailState extends State<_TxDetail> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final settings = ref.watch(settingsProvider);
        final tx = widget.tx;
        final isDebt = tx.paymentMethod == AppConstants.paymentPiutang;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Detail Transaksi', style: Theme.of(context).textTheme.titleLarge),
                      const Spacer(),
                      IconButton(
                        onPressed: () async {
                          final ok = await showConfirmDialog(context,
                              title: 'Hapus Transaksi',
                              content: 'Yakin ingin menghapus transaksi ini? Data stok tidak akan kembali otomatis.',
                              confirmLabel: 'HAPUS',
                              confirmColor: AppTheme.danger);
                          if (ok) {
                            await ref.read(transactionRepositoryProvider).deleteTransaction(tx.id);
                            await ref.read(transactionsProvider.notifier).refresh();
                            if (context.mounted) showSuccess(context, 'Transaksi berhasil dihapus');
                          }
                        },
                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                        tooltip: 'Hapus Transaksi',
                      ),
                      IconButton(
                        onPressed: () => InvoiceHelper.saveInvoice(tx, settings),
                        icon: const Icon(Icons.download, size: 20, color: AppTheme.accent),
                        tooltip: 'Cetak/Download PDF',
                      ),
                      IconButton(
                        onPressed: () => InvoiceHelper.shareInvoice(tx, settings),
                        icon: const Icon(Icons.share_rounded, size: 20, color: AppTheme.accent),
                        tooltip: 'Share PDF',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(tx.invoiceNumber,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', color: AppTheme.accent)),
                      ),
                      if (isDebt) _DebtStatusBadge(tx: tx),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(Formatters.dateTime(tx.createdAt), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (tx.customerName != null) ...[
                        _infoRow(context, 'Pelanggan', tx.customerName!),
                        const SizedBox(height: 4),
                      ],
                      _infoRow(context, 'Kasir', tx.cashierName ?? 'Admin'),
                      const Divider(color: AppTheme.border, height: 32),
                      Text('Item Pesanan', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.accent, letterSpacing: 0.5)),
                      const SizedBox(height: 16),
                      ...tx.items.map((item) => _DetailItemRow(key: ValueKey('item_${item.id}'), item: item)),
                      const Divider(color: AppTheme.border, height: 32),
                      _row(context, 'Subtotal Item', Formatters.currency(tx.subtotal)),
                      if (tx.itemDiscountTotal > 0) _row(context, 'Total Pot. Item', '- ${Formatters.currency(tx.itemDiscountTotal)}', AppTheme.success),
                      if (tx.transDiscountAmount > 0) _row(context, 'Diskon Transaksi', '- ${Formatters.currency(tx.transDiscountAmount)}', AppTheme.success),
                      if (tx.taxAmount > 0) _row(context, 'PPN (11%)', Formatters.currency(tx.taxAmount)),
                      const SizedBox(height: 8),
                      _row(context, 'TOTAL', Formatters.currency(tx.total), AppTheme.accent, true),
                      const Divider(color: AppTheme.border, height: 32),
                      _row(context, 'Metode Pembayaran', tx.paymentMethod),
                      _row(context, 'Dibayar', Formatters.currency(tx.amountPaid)),
                      _row(context, 'Kembalian', Formatters.currency(tx.changeAmount), AppTheme.success),
                      if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                        const Divider(color: AppTheme.border, height: 32),
                        Text('Catatan:', style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(tx.notes!, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Row(children: [
      Text('$label:', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(width: 8),
      Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _row(BuildContext context, String label, String value, [Color? color, bool bold = false]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary)),
        const Spacer(),
        Text(value, style: TextStyle(
          color:      color ?? AppTheme.textPrimary,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          fontSize:   bold ? 18 : 14,
        )),
      ]),
    );
  }
}

class _DetailItemRow extends StatelessWidget {
  final TransactionItem item;
  const _DetailItemRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(item.productName, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2)),
              ),
              const SizedBox(width: 16),
              Text(Formatters.currency(item.subtotal), 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${Formatters.decimal(item.quantity)} ${item.unitName} × ${Formatters.currency(item.soldPrice)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
              if (item.soldPrice != item.originalPrice) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('HARGA DIUBAH', style: TextStyle(color: AppTheme.warning, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          if (item.discountValue > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Diskon: -${Formatters.currency(item.totalDiscount)}',
                style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}
