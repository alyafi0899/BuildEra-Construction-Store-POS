import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../models/customer.dart';
import '../../models/debt.dart';
import '../../models/debt_payment.dart';
import '../../providers/debt_repository.dart';
import '../../utils/debt_report_helper.dart';
import '../../utils/debt_invoice_helper.dart';
import '../../../payment/providers/transaction_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../shared/widgets/security_gate.dart';

class CustomerDebtDetailPage extends ConsumerWidget {
  final Customer customer;
  const CustomerDebtDetailPage({required this.customer, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch the stream instead of using the passed object to get updates
    final customersAsync = ref.watch(customersProvider);
    final currentCustomer = customersAsync.asData?.value.firstWhere((c) => c.id == customer.id, orElse: () => customer) ?? customer;
    
    final debtsAsync = ref.watch(debtsProvider(customer.id));
    final paymentsAsync = ref.watch(debtPaymentsProvider((customerId: customer.id, debtId: null)));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Text('Detail Piutang: ${currentCustomer.name}'),
        backgroundColor: AppTheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () async {
              final debts = debtsAsync.asData?.value ?? [];
              await DebtReportHelper.exportCustomerDetailToExcel(currentCustomer, debts);
            },
            icon: const Icon(Icons.file_download_outlined, color: AppTheme.accent),
            tooltip: 'Export Excel',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Summary Header
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.surface,
            child: Row(
              children: [
                Expanded(child: _infoBox(context, 'Total Piutang', Formatters.currency(currentCustomer.totalOutstanding), color: AppTheme.warning)),
                const SizedBox(width: 16),
                Expanded(child: _infoBox(context, 'Telepon', currentCustomer.phone)),
                const SizedBox(width: 16),
                Expanded(child: _infoBox(context, 'Alamat', currentCustomer.address ?? '—')),
              ],
            ),
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Debts List (Transactions) ────────────────────────────
                Expanded(
                  flex: 3,
                  child: _buildSection(
                    title: 'Daftar Transaksi Piutang',
                    child: debtsAsync.when(
                      loading: () => const AppLoading(),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (debts) => _DebtList(
                        debts: debts,
                        onRecordPayment: (d) => _showPaymentForm(context, d),
                      ),
                    ),
                  ),
                ),

                const VerticalDivider(width: 1, color: AppTheme.border),

                // ── Payments History ──────────────────────────────────────
                Expanded(
                  flex: 2,
                  child: _buildSection(
                    title: 'Riwayat Pembayaran',
                    child: paymentsAsync.when(
                      loading: () => const AppLoading(),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (payments) => _PaymentHistoryList(payments: payments),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBox(BuildContext context, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(value, style: TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.bold, 
          color: color ?? AppTheme.textPrimary,
        )),
      ],
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.accent)),
        ),
        Expanded(child: child),
      ],
    );
  }

  void _showPaymentForm(BuildContext context, Debt debt) {
    showDialog(
      context: context,
      builder: (context) => _RecordPaymentDialog(debt: debt),
    );
  }
}

class _DebtList extends StatelessWidget {
  final List<Debt> debts;
  final Function(Debt) onRecordPayment;

  const _DebtList({required this.debts, required this.onRecordPayment});

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) return const EmptyState(icon: Icons.receipt_outlined, title: 'Tidak ada transaksi piutang');

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: debts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _DebtTile(debt: debts[i], onRecordPayment: onRecordPayment),
    );
  }
}

class _DebtTile extends ConsumerStatefulWidget {
  final Debt debt;
  final Function(Debt) onRecordPayment;
  const _DebtTile({required this.debt, required this.onRecordPayment});

  @override
  ConsumerState<_DebtTile> createState() => _DebtTileState();
}

class _DebtTileState extends ConsumerState<_DebtTile> {
  final bool _expanded = true; // Always expanded for full detail visibility as requested

  @override
  Widget build(BuildContext context) {
    final d = widget.debt;
    final bool isPaid = d.status == DebtStatus.paid;
    final transactionAsync = ref.watch(transactionByIdProvider(d.transactionId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPaid ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Text(d.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          const SizedBox(width: 8),
                          StatusChip(label: _statusLabel(d.status), color: _statusColor(d.status)),
                          if (d.isOverdue) ...[
                            const SizedBox(width: 8),
                            const StatusChip(label: 'TERLAMBAT', color: AppTheme.danger),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Jatuh Tempo: ${Formatters.date(d.dueDate)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Sisa Piutang', style: Theme.of(context).textTheme.bodySmall),
                  Text(Formatters.currency(d.remainingBalance), style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () async {
                  final settings = ref.read(settingsProvider);
                  final payments = await ref.read(debtRepositoryProvider).getPayments(customerId: d.customerId, debtId: d.id);
                  final customers = ref.read(customersProvider).asData?.value ?? [];
                  final customer = customers.firstWhere((c) => c.id == d.customerId);
                  final transaction = await ref.read(transactionByIdProvider(d.transactionId).future);
                  await DebtInvoiceHelper.printDebtInvoice(customer, d, payments, settings, transaction: transaction);
                },
                icon: const Icon(Icons.print_rounded, size: 20, color: AppTheme.accent),
                tooltip: 'Print Nota Piutang',
              ),
              IconButton(
                onPressed: () async {
                  final settings = ref.read(settingsProvider);
                  final payments = await ref.read(debtRepositoryProvider).getPayments(customerId: d.customerId, debtId: d.id);
                  final customers = ref.read(customersProvider).asData?.value ?? [];
                  final customer = customers.firstWhere((c) => c.id == d.customerId);
                  final transaction = await ref.read(transactionByIdProvider(d.transactionId).future);
                  await DebtInvoiceHelper.downloadDebtInvoice(customer, d, payments, settings, transaction: transaction);
                },
                icon: const Icon(Icons.download_rounded, size: 20, color: AppTheme.accent),
                tooltip: 'Simpan Nota Piutang',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  final ok = await showConfirmDialog(context, 
                    title: 'Hapus Piutang', 
                    content: 'Yakin ingin menghapus catatan piutang ini beserta riwayat pembayarannya?',
                    confirmLabel: 'HAPUS',
                    confirmColor: AppTheme.danger
                  );
                  if (ok) {
                    if (context.mounted) {
                      requirePin(context, ref, () async {
                        await ref.read(debtRepositoryProvider).deleteDebt(d.id);
                        if (context.mounted) showSuccess(context, 'Piutang berhasil dihapus');
                      });
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                tooltip: 'Hapus Piutang',
              ),
              const SizedBox(width: 8),
              if (!isPaid)
                ElevatedButton(
                  onPressed: () => widget.onRecordPayment(d),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Bayar'),
                )
              else
                const Icon(Icons.check_circle_rounded, color: AppTheme.success),
            ],
          ),
          
          if (_expanded) ...[
            const Divider(height: 24),
            transactionAsync.when(
              data: (tx) {
                if (tx == null) return const Text('Data transaksi tidak ditemukan');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RINCIAN PRODUK:', 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.5)),
                    const SizedBox(height: 12),
                    ...tx.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 4, color: AppTheme.accent)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.productName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('${Formatters.decimal(item.quantity)} ${item.unitName} × ${Formatters.currency(item.soldPrice)}', 
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          Text(Formatters.currency(item.subtotal), 
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
                    const Divider(height: 24, thickness: 0.5, color: AppTheme.border),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('TOTAL TRANSAKSI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(Formatters.currency(tx.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.accent)),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text('Gagal memuat rincian: $e', style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(DebtStatus s) {
    switch(s) {
      case DebtStatus.unpaid: return 'BELUM LUNAS';
      case DebtStatus.partiallyPaid: return 'CICILAN';
      case DebtStatus.paid: return 'LUNAS';
      case DebtStatus.overdue: return 'TERLAMBAT';
    }
  }

  Color _statusColor(DebtStatus s) {
    switch(s) {
      case DebtStatus.unpaid: return AppTheme.textSecondary;
      case DebtStatus.partiallyPaid: return AppTheme.info;
      case DebtStatus.paid: return AppTheme.success;
      case DebtStatus.overdue: return AppTheme.danger;
    }
  }
}

class _PaymentHistoryList extends StatelessWidget {
  final List<DebtPayment> payments;
  const _PaymentHistoryList({required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) return const EmptyState(icon: Icons.history_rounded, title: 'Belum ada pembayaran');

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: payments.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.border),
      itemBuilder: (context, i) {
        final p = payments[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Formatters.currency(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                    Text(Formatters.dateTime(p.createdAt), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (p.notes != null)
                Text(p.notes!, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  final Debt debt;
  const _RecordPaymentDialog({required this.debt});

  @override
  ConsumerState<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl.text = widget.debt.remainingBalance.toStringAsFixed(0);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = Formatters.parseDecimal(_amountCtrl.text);
    if (amount <= 0) return;
    
    setState(() => _loading = true);
    try {
      await ref.read(debtRepositoryProvider).recordPayment(
        debtId:     widget.debt.id,
        customerId: widget.debt.customerId,
        amount:     amount,
        notes:      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Pembayaran berhasil dicatat');
      }
    } catch (e) {
      if (mounted) showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Catat Pembayaran'),
      content: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('No. Invoice', widget.debt.invoiceNumber),
            _infoRow('Sisa Piutang', Formatters.currency(widget.debt.remainingBalance)),
            const Divider(height: 32),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Jumlah Bayar',
                prefixText: 'Rp ',
              ),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Catatan (Opsional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const AppLoading() : const Text('Simpan Pembayaran'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
