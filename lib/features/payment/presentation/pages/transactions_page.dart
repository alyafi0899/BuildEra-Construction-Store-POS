import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/transaction_provider.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  Transaction? _selected;

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
                return ListView.separated(
                  padding:   const EdgeInsets.all(20),
                  itemCount: txs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _TxCard(
                    tx:       txs[i],
                    selected: _selected?.id == txs[i].id,
                    onTap:    () => setState(() => _selected = _selected?.id == txs[i].id ? null : txs[i]),
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

class _TxDetail extends StatelessWidget {
  final Transaction tx;
  const _TxDetail({required this.tx});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Detail Transaksi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(tx.invoiceNumber,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', color: AppTheme.accent)),
          const SizedBox(height: 4),
          Text(Formatters.dateTime(tx.createdAt), style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
      Expanded(
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Item', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.accent)),
              const SizedBox(height: 12),
              ...tx.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.productName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                    Text('${Formatters.decimal(item.quantity)} ${item.unitName} × ${Formatters.currency(item.unitPrice)}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
                  Text(Formatters.currency(item.subtotal), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                ]),
              )),
              const Divider(color: AppTheme.border, height: 24),
              _row(context, 'Subtotal', Formatters.currency(tx.subtotal)),
              if (tx.discount > 0) _row(context, 'Diskon', '- ${Formatters.currency(tx.discount)}', AppTheme.success),
              if (tx.taxAmount > 0) _row(context, 'PPN', Formatters.currency(tx.taxAmount)),
              const SizedBox(height: 8),
              _row(context, 'TOTAL', Formatters.currency(tx.total), AppTheme.accent),
              const Divider(color: AppTheme.border, height: 24),
              _row(context, 'Metode', tx.paymentMethod),
              _row(context, 'Dibayar', Formatters.currency(tx.amountPaid)),
              _row(context, 'Kembalian', Formatters.currency(tx.changeAmount), AppTheme.success),
            ]),
          ),
        ),
      ),
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
