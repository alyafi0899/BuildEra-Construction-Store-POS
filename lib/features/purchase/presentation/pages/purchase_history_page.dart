import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/models/purchase.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/purchase_provider.dart';
import '../../utils/purchase_invoice_helper.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../shared/widgets/security_gate.dart';

class PurchaseHistoryPage extends ConsumerStatefulWidget {
  const PurchaseHistoryPage({super.key});

  @override
  ConsumerState<PurchaseHistoryPage> createState() => _PurchaseHistoryPageState();
}

class _PurchaseHistoryPageState extends ConsumerState<PurchaseHistoryPage> {
  Purchase? _selected;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesProvider);
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 800;

    Widget buildListSection() => Column(
          children: [
            PageHeader(
              title: 'Riwayat Pembelian',
              subtitle: 'Daftar semua nota barang masuk dari supplier',
              icon: Icons.history_edu_rounded,
              actions: [
                IconButton(
                  onPressed: () => ref.refresh(purchasesProvider),
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
                ),
              ],
            ),

            // Search Bar
            Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 12 : 24, vertical: 12),
              color: AppTheme.surface,
              child: AppSearchField(
                controller: _searchCtrl,
                hintText: 'Cari nomor nota atau supplier...',
                onChanged: (v) => setState(() => _search = v),
                onClear: () => setState(() {
                  _search = '';
                  _searchCtrl.clear();
                }),
              ),
            ),

            Expanded(
              child: purchasesAsync.when(
                data: (list) {
                  final filtered = list.where((p) {
                    final s = _search.toLowerCase();
                    return p.invoiceNumber.toLowerCase().contains(s) ||
                        (p.supplierName?.toLowerCase().contains(s) ?? false);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Belum ada riwayat pembelian',
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.all(isCompact ? 12 : 20),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final isSelected = _selected?.id == p.id;
                      return _PurchaseCard(
                        purchase: p,
                        isSelected: isSelected,
                        onTap: () => setState(() => _selected = isSelected ? null : p),
                      );
                    },
                  );
                },
                loading: () => const AppLoading(),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        );

    Widget buildDetailView() => Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.surface,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _selected = null),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.accent),
                    tooltip: 'Kembali ke Daftar',
                  ),
                  const SizedBox(width: 8),
                  const Text('Detail Pembelian',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
            Expanded(
              child: _PurchaseDetailView(
                purchase: _selected!,
                onClear: () => setState(() => _selected = null),
              ),
            ),
          ],
        );

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: isCompact
          ? (_selected != null ? buildDetailView() : buildListSection())
          : Row(
              children: [
                // ── Left: Purchase List ───────────────────────────────────────────
                Expanded(
                  flex: 6,
                  child: buildListSection(),
                ),

                // ── Right: Purchase Detail ────────────────────────────────────────
                if (_selected != null)
                  SizedBox(
                    width: 450,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppTheme.surface,
                        border: Border(left: BorderSide(color: AppTheme.border)),
                      ),
                      child: _PurchaseDetailView(
                        purchase: _selected!,
                        onClear: () => setState(() => _selected = null),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final Purchase purchase;
  final bool isSelected;
  final VoidCallback onTap;

  const _PurchaseCard({required this.purchase, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppTheme.accent.withValues(alpha: 0.1) : AppTheme.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: isSelected ? AppTheme.accent : AppTheme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_shipping_rounded, color: AppTheme.accent, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(purchase.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                    Text(purchase.supplierName ?? 'Supplier Umum', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Formatters.currency(purchase.total), style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.accent)),
                  Text(Formatters.dateTime(purchase.createdAt), style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseDetailView extends ConsumerWidget {
  final Purchase purchase;
  final VoidCallback onClear;
  const _PurchaseDetailView({required this.purchase, required this.onClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Detail Pembelian', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  const Spacer(),
                  IconButton(
                    onPressed: () async {
                      final ok = await showConfirmDialog(context,
                          title: 'Hapus Riwayat Pembelian',
                          content: 'Yakin ingin menghapus nota ini? Stok produk akan dikurangi kembali secara otomatis.',
                          confirmLabel: 'HAPUS',
                          confirmColor: AppTheme.danger);
                      if (ok) {
                        if (context.mounted) {
                          requirePin(context, ref, () async {
                            await ref.read(purchaseActionProvider.notifier).deletePurchase(purchase.id);
                            onClear();
                            if (context.mounted) {
                              showSuccess(context, 'Nota pembelian berhasil dihapus');
                            }
                          });
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.danger),
                    tooltip: 'Hapus Nota',
                  ),
                  IconButton(
                    onPressed: () => onClear(),
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // New Organized Print Buttons
              Row(
                children: [
                  Expanded(
                    child: _PrintActionBtn(
                      label: 'STRUK THERMAL',
                      icon: Icons.receipt_long_rounded,
                      color: AppTheme.accent,
                      onPrint: () => PurchaseInvoiceHelper.printInvoice(purchase, settings),
                      onDownload: () => PurchaseInvoiceHelper.saveInvoiceThermal(purchase, settings),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PrintActionBtn(
                      label: 'NOTA A4 (PDF)',
                      icon: Icons.picture_as_pdf_rounded,
                      color: AppTheme.info,
                      onPrint: () => PurchaseInvoiceHelper.printInvoiceA4(purchase, settings),
                      onDownload: () => PurchaseInvoiceHelper.saveInvoice(purchase, settings),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _infoRow('No. Nota', purchase.invoiceNumber),
              _infoRow('Supplier', purchase.supplierName ?? 'Umum'),
              _infoRow('Tanggal', Formatters.dateTime(purchase.createdAt)),
              _infoRow('Metode', purchase.paymentMethod),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: purchase.items.length,
            separatorBuilder: (_, __) => const Divider(height: 24),
            itemBuilder: (context, i) {
              final item = purchase.items[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${Formatters.decimal(item.quantity)} ${item.unitName} × ${Formatters.currency(item.purchasePrice)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const Spacer(),
                      Text(Formatters.currency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.surfaceAlt,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Column(
            children: [
              _summaryRow('Subtotal', purchase.subtotal),
              _summaryRow('Biaya Kirim', purchase.shippingFee),
              const Divider(height: 24),
              _summaryRow('TOTAL', purchase.total, isBold: true, size: 18, color: AppTheme.accent),
              const SizedBox(height: 8),
              _summaryRow('Dibayar', purchase.amountPaid, color: AppTheme.success),
              if (purchase.total > purchase.amountPaid)
                _summaryRow('Sisa Hutang', purchase.total - purchase.amountPaid, color: AppTheme.warning),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double val, {bool isBold = false, double size = 13, Color? color}) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        const Spacer(),
        Text(Formatters.currency(val), style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

class _PrintActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onPrint;
  final Future<void> Function() onDownload;

  const _PrintActionBtn({
    required this.label, 
    required this.icon, 
    required this.color, 
    required this.onPrint, 
    required this.onDownload
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _runAction(context, onPrint),
                  icon: const Icon(Icons.print_rounded, size: 14),
                  label: const Text('CETAK', style: TextStyle(fontSize: 10)),
                  style: TextButton.styleFrom(foregroundColor: color),
                ),
              ),
              Container(width: 1, height: 20, color: color.withValues(alpha: 0.2)),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _runAction(context, onDownload),
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: const Text('UNDUH', style: TextStyle(fontSize: 10)),
                  style: TextButton.styleFrom(foregroundColor: color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _runAction(
      BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        showError(context, 'Gagal mencetak nota pembelian: $e');
      }
    }
  }
}
