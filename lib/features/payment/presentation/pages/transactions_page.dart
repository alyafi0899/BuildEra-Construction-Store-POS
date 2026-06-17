import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/utils/invoice_helper.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../../cashier/models/cart_item.dart';

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
      body: Row(children: [
        // List
        Expanded(
          flex: 5,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: AppTheme.surface,
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Riwayat Transaksi', style: Theme.of(context).textTheme.headlineLarge),
                  Text('Semua transaksi yang telah selesai', style: Theme.of(context).textTheme.bodyMedium),
                ]),
                const Spacer(),
                IconButton(
                  onPressed: () => ref.read(transactionsProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
                ),
              ]),
            ),
            Expanded(child: txAsync.when(
              loading: () => const AppLoading(),
              error:   (e, _) => Center(child: Text('Error: $e')),
              data: (txs) {
                if (txs.isEmpty) {
                  return const EmptyState(
                    icon:     Icons.receipt_long_outlined,
                    title:    'Belum ada transaksi',
                    subtitle: 'Transaksi akan muncul di sini setelah pembayaran selesai',
                  );
                }
                return Scrollbar(
                  controller: _listScrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    controller: _listScrollController,
                    padding:   const EdgeInsets.all(20),
                    itemCount: txs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _TxCard(
                      tx:       txs[i],
                      selected: _selected?.id == txs[i].id,
                      onTap:    () => setState(() => _selected = _selected?.id == txs[i].id ? null : txs[i]),
                    ),
                  ),
                );
              },
            )),
          ]),
        ),

        // Detail panel
        if (_selected != null)
          Container(
            width: 360,
            decoration: const BoxDecoration(
              color:  AppTheme.surface,
              border: Border(left: BorderSide(color: AppTheme.border)),
            ),
            child: _TxDetail(tx: _selected!),
          ),
      ]),
    );
  }
}

class _TxCard extends StatelessWidget {
  final Transaction tx;
  final bool        selected;
  final VoidCallback onTap;
  const _TxCard({required this.tx, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
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
            StatusChip(label: tx.paymentMethod, color: _methodColor(tx.paymentMethod)),
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

class _TxDetail extends StatefulWidget {
  final Transaction tx;
  const _TxDetail({required this.tx});

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

        return Column(children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(
                children: [
                  Text('Detail Transaksi', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    onPressed: () => InvoiceHelper.printInvoice(tx, settings),
                    icon: const Icon(Icons.print_rounded, size: 20, color: AppTheme.accent),
                  ),
                  IconButton(
                    onPressed: () => InvoiceHelper.shareInvoice(tx, settings),
                    icon: const Icon(Icons.share_rounded, size: 20, color: AppTheme.accent),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(tx.invoiceNumber,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', color: AppTheme.accent)),
              const SizedBox(height: 4),
              Text(Formatters.dateTime(tx.createdAt), style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (tx.customerName != null) ...[
                    _infoRow(context, 'Pelanggan', tx.customerName!),
                    const SizedBox(height: 4),
                  ],
                  _infoRow(context, 'Kasir', tx.cashierName ?? 'Admin'),
                  const Divider(color: AppTheme.border, height: 32),
                  
                  Text('Item', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.accent)),
                  const SizedBox(height: 12),
                  ...tx.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(item.productName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13))),
                          Text(Formatters.currency(item.subtotal), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                        ]),
                        Row(children: [
                          Text('${Formatters.decimal(item.quantity)} ${item.unitName} × ${Formatters.currency(item.soldPrice)}',
                              style: Theme.of(context).textTheme.bodySmall),
                          const Spacer(),
                          if (item.soldPrice != item.originalPrice)
                            Text('(Harga Kurang)', style: const TextStyle(color: AppTheme.warning, fontSize: 10, fontWeight: FontWeight.bold)),
                        ]),
                        if (item.discountValue > 0)
                          Text('Potongan Item: -${Formatters.currency(item.discountValue)}${item.discountType == DiscountType.percentage ? '%' : ''}',
                              style: const TextStyle(color: AppTheme.success, fontSize: 10)),
                      ],
                    ),
                  )),
                  
                  const Divider(color: AppTheme.border, height: 24),
                  _row(context, 'Subtotal Item', Formatters.currency(tx.subtotal)),
                  if (tx.itemDiscountTotal > 0) 
                    _row(context, 'Total Pot. Item', '- ${Formatters.currency(tx.itemDiscountTotal)}', AppTheme.success),
                  if (tx.transDiscountAmount > 0) 
                    _row(context, 'Diskon Transaksi', '- ${Formatters.currency(tx.transDiscountAmount)}', AppTheme.success),
                  if (tx.taxAmount > 0) 
                    _row(context, 'PPN (11%)', Formatters.currency(tx.taxAmount)),
                    
                  const SizedBox(height: 8),
                  _row(context, 'TOTAL', Formatters.currency(tx.total), AppTheme.accent, true),
                  
                  const Divider(color: AppTheme.border, height: 24),
                  _row(context, 'Metode', tx.paymentMethod),
                  _row(context, 'Dibayar', Formatters.currency(tx.amountPaid)),
                  _row(context, 'Kembalian', Formatters.currency(tx.changeAmount), AppTheme.success),
                  
                  if (tx.notes != null) ...[
                    const Divider(color: AppTheme.border, height: 24),
                    Text('Catatan:', style: Theme.of(context).textTheme.bodySmall),
                    Text(tx.notes!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ]),
              ),
            ),
          ),
        ]);
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(value, style: TextStyle(
          color:      color ?? AppTheme.textPrimary,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          fontSize:   bold ? 16 : 13,
        )),
      ]),
    );
  }
}
