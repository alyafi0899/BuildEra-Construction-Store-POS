import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../core/utils/invoice_helper.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/security_gate.dart';

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String? _methodFilter;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txAsync = ref.watch(transactionsProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          PageHeader(
            title: 'Riwayat Transaksi',
            subtitle: 'Daftar penjualan toko',
            icon: Icons.receipt_long_rounded,
            actions: [
              IconButton(
                onPressed: () => ref.refresh(transactionsProvider),
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
              ),
            ],
          ),

          // Filters Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchCtrl,
                    hintText: 'Cari invoice...',
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                const SizedBox(width: 8),
                _FilterDropdown(
                  value: _methodFilter,
                  onChanged: (v) => setState(() => _methodFilter = v),
                ),
              ],
            ),
          ),

          Expanded(
            child: txAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (txs) {
                final filtered = txs.where((t) {
                  final matchSearch = _search.isEmpty || t.invoiceNumber.toLowerCase().contains(_search.toLowerCase());
                  final matchMethod = _methodFilter == null || t.paymentMethod == _methodFilter;
                  return matchSearch && matchMethod;
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.receipt_long_outlined, title: 'Tidak ada transaksi');
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _TransactionCard(
                    tx: filtered[i],
                    onTap: () => _showTransactionDetail(context, filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetail(BuildContext context, Transaction tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (_) => _TransactionDetailSheet(tx: tx),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButton<String?>(
        value: value,
        hint: const Text('Semua', style: TextStyle(fontSize: 13)),
        underline: const SizedBox(),
        items: [
          const DropdownMenuItem(value: null, child: Text('Semua')),
          ...AppConstants.paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m))),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onTap;

  const _TransactionCard({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_rounded, color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(Formatters.dateTime(tx.createdAt), style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.currency(tx.total), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              StatusChip(label: tx.paymentMethod, color: AppTheme.info),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionDetailSheet extends ConsumerWidget {
  final Transaction tx;
  const _TransactionDetailSheet({required this.tx});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Column(
      children: [
        Container(
          height: 5, width: 40,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(5)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('Detail Penjualan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              IconButton(
                onPressed: () => InvoiceHelper.shareInvoice(tx, settings),
                icon: const Icon(Icons.share_rounded, color: AppTheme.primary),
              ),
              IconButton(
                onPressed: () => _deleteTx(context, ref),
                icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _infoTile('No. Invoice', tx.invoiceNumber),
              _infoTile('Waktu', Formatters.dateTime(tx.createdAt)),
              _infoTile('Kasir', tx.cashierName ?? 'Admin'),
              if (tx.customerName != null) _infoTile('Pelanggan', tx.customerName!),
              const Divider(height: 32),
              const Text('ITEM PESANAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              ...tx.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${Formatters.decimal(item.quantity)} ${item.unitName} x ${Formatters.currency(item.soldPrice)}'),
                        ],
                      ),
                    ),
                    Text(Formatters.currency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
              const Divider(height: 32),
              _summaryRow('Subtotal', tx.subtotal),
              if (tx.itemDiscountTotal > 0) _summaryRow('Diskon Item', -tx.itemDiscountTotal, color: AppTheme.success),
              if (tx.transDiscountAmount > 0) _summaryRow('Diskon Transaksi', -tx.transDiscountAmount, color: AppTheme.success),
              if (tx.taxAmount > 0) _summaryRow('PPN (11%)', tx.taxAmount),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  Text(Formatters.currency(tx.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 24),
              AppCard(
                color: AppTheme.surfaceAlt,
                child: Column(
                  children: [
                    _summaryRow('Metode Pembayaran', tx.paymentMethod, isCurrency: false),
                    _summaryRow('Dibayar', tx.amountPaid),
                    _summaryRow('Kembalian', tx.changeAmount, color: AppTheme.success),
                  ],
                ),
              ),
              if (tx.notes != null && tx.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Catatan: ${tx.notes}', style: const TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textMuted)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoTile(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted)),
        const Spacer(),
        Text(val, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _summaryRow(String label, dynamic val, {Color? color, bool isCurrency = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 13)),
        const Spacer(),
        Text(
          isCurrency ? Formatters.currency(val as double) : val.toString(),
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
      ]),
    );
  }

  Future<void> _deleteTx(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context,
      title: 'Hapus Transaksi',
      content: 'Stok akan dikembalikan secara otomatis. Lanjutkan?',
    );
    if (ok) {
      requirePin(context, ref, () async {
        await ref.read(transactionsActionProvider.notifier).deleteTransaction(tx.id);
        if (context.mounted) {
          Navigator.pop(context);
          showSuccess(context, 'Transaksi dihapus');
        }
      });
    }
  }
}
