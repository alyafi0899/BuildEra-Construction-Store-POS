import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/core/utils/formatters.dart';
import 'package:buildera/shared/widgets/common_widgets.dart';
import 'package:buildera/features/payment/providers/transaction_provider.dart';
import 'package:buildera/shared/models/transaction.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  Transaction? _selectedTx;

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(children: [
        // ── Left: List ──────────────────────────────────────────────────
        Expanded(
          flex: 4,
          child: Column(children: [
            PageHeader(
              title: 'Riwayat Transaksi',
              subtitle: 'Daftar nota dan penjualan toko',
              icon: Icons.history_rounded,
              actions: [
                IconButton(
                  onPressed: () => ref.read(transactionsProvider.notifier).refresh(),
                  icon: Icon(Icons.refresh_rounded, color: colorScheme.primary),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            
            Expanded(
              child: transactionsAsync.when(
                loading: () => const AppLoading(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (list) {
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Belum ada transaksi',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: list.length,
                    itemBuilder: (context, i) => _TransactionTile(
                      tx: list[i],
                      selected: _selectedTx?.id == list[i].id,
                      onTap: () => setState(() => _selectedTx = list[i]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),

        // ── Right: Details ──────────────────────────────────────────────
        Container(
          width: 420,
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(left: BorderSide(color: colorScheme.outline, width: 1)),
          ),
          child: _selectedTx == null
              ? const EmptyState(
                  icon: Icons.info_outline_rounded,
                  title: 'Pilih Transaksi',
                  subtitle: 'Klik pada salah satu riwayat untuk melihat detail',
                )
              : _TransactionDetail(tx: _selectedTx!),
        ),
      ]),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction tx;
  final bool selected;
  final VoidCallback onTap;

  const _TransactionTile({required this.tx, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: selected ? colorScheme.primary : colorScheme.outline),
      ),
      child: Material(
        color: selected ? colorScheme.primary.withValues(alpha: 0.1) : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_rounded, color: colorScheme.primary, size: 20),
          ),
          title: Row(
            children: [
              Text(tx.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              Text(Formatters.currency(tx.total), style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(Formatters.dateTime(tx.createdAt), style: const TextStyle(fontSize: 12)),
                const Text(' • '),
                Text('${tx.items.length} item', style: const TextStyle(fontSize: 12)),
                const Spacer(),
                StatusChip(label: tx.paymentMethod.toUpperCase(), color: _methodColor(context, tx.paymentMethod)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _methodColor(BuildContext context, String m) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (m.toLowerCase()) {
      case 'tunai': return const Color(0xFF2ECC71);
      case 'qris': return const Color(0xFF3498DB);
      case 'piutang': return colorScheme.primary;
      default: return colorScheme.onSurface.withValues(alpha: 0.5);
    }
  }
}

class _TransactionDetail extends StatelessWidget {
  final Transaction tx;
  const _TransactionDetail({required this.tx});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPaid = tx.paymentMethod.toLowerCase() != 'piutang';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colorScheme.outline)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Detail Transaksi', style: Theme.of(context).textTheme.headlineSmall),
                  const Spacer(),
                  StatusChip(
                    label: isPaid ? 'LUNAS' : 'PIUTANG',
                    color: isPaid ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(tx.invoiceNumber, style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _infoRow('Waktu', Formatters.dateTime(tx.createdAt)),
              _infoRow('Kasir', tx.cashierName ?? 'Admin'),
              _infoRow('Pelanggan', tx.customerName ?? 'Umum'),
              _infoRow('Metode', tx.paymentMethod.toUpperCase()),
              const Divider(height: 48),
              Text('DAFTAR ITEM', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 1)),
              const SizedBox(height: 16),
              ...tx.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${Formatters.decimal(item.quantity)} ${item.unitName} x ${Formatters.currency(item.soldPrice)}', style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    Text(Formatters.currency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
              const Divider(height: 48),
              _summaryRow('Subtotal', tx.subtotal),
              if (tx.transDiscountAmount > 0) _summaryRow('Total Diskon', -tx.transDiscountAmount, color: const Color(0xFF2ECC71)),
              if (tx.taxAmount > 0) _summaryRow('PPN (11%)', tx.taxAmount),
              const SizedBox(height: 12),
              _summaryRow('TOTAL AKHIR', tx.total, isBold: true, fontSize: 18),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {}, // TODO: Re-print
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('CETAK ULANG NOTA'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false, double fontSize = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize)),
          const Spacer(),
          Text(Formatters.currency(value), style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: fontSize, color: color)),
        ],
      ),
    );
  }
}
