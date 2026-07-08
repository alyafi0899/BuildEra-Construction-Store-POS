import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:buildera/core/utils/formatters.dart';
import 'package:buildera/shared/widgets/common_widgets.dart';
import 'package:buildera/features/products/providers/product_provider.dart';
import 'package:buildera/features/inventory/providers/restock_provider.dart';
import 'package:buildera/features/inventory/providers/bill_payment_provider.dart';
import 'package:buildera/features/inventory/models/bill_payment.dart';
import 'package:buildera/features/inventory/models/restock_record.dart';
import 'package:buildera/shared/models/product.dart';
import 'package:buildera/features/products/models/product_financials.dart';

class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key});

  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filter = 'unpaid'; // unpaid, paid, all

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final restocksAsync = ref.watch(restockHistoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const PageHeader(
            title: 'Manajemen Tagihan',
            subtitle: 'Pantau riwayat biaya dan kelola hutang operasional',
            icon: Icons.receipt_long_rounded,
          ),

          // ── Stats Summary ─────────────────────────────────────────────
          if (productsAsync.hasValue && restocksAsync.hasValue)
            _buildStatsHeader(productsAsync.value!, restocksAsync.value!),

          // ── Tabs ──────────────────────────────────────────────────────
          Container(
            color: colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Tagihan Supplier'),
                Tab(text: 'Tagihan Ekspedisi'),
              ],
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.5),
              indicatorColor: colorScheme.primary,
              indicatorWeight: 3,
            ),
          ),

          // ── Filter Chips ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outline)),
            ),
            child: Row(
              children: [
                _filterChip('Belum Lunas', 'unpaid'),
                const SizedBox(width: 8),
                _filterChip('Sudah Lunas', 'paid'),
                const SizedBox(width: 8),
                _filterChip('Semua', 'all'),
              ],
            ),
          ),

          // ── List Content ──────────────────────────────────────────────
          Expanded(
            child: (productsAsync.hasValue && restocksAsync.hasValue)
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildEntityGroupedList(productsAsync.value!, restocksAsync.value!, true),
                      _buildEntityGroupedList(productsAsync.value!, restocksAsync.value!, false),
                    ],
                  )
                : const AppLoading(),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    final colorScheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, color: active ? colorScheme.onPrimary : colorScheme.onSurface)),
      selected: active,
      onSelected: (v) => setState(() => _filter = value),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildStatsHeader(List<Product> products, List<RestockRecord> restocks) {
    double totalCost = 0;
    double totalPaid = 0;
    int unpaidCount = 0;

    void process(double amount, double paid, PaymentStatus status) {
      if (status == PaymentStatus.notApplicable) return;
      totalCost += amount;
      totalPaid += paid;
      if (amount - paid > 0.5) unpaidCount++;
    }

    for (var p in products) {
      process(p.financials.supplierPrice, p.financials.supplierPaidAmount, p.financials.supplierPaymentStatus);
      process(p.financials.supplierShippingCost, p.financials.shippingPaidAmount, p.financials.shippingPaymentStatus);
    }
    for (var r in restocks) {
      process(r.supplierPrice, r.supplierPaidAmount, r.supplierPaymentStatus);
      process(r.shippingCost, r.shippingPaidAmount, r.shippingPaymentStatus);
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      color: colorScheme.surface,
      child: Row(
        children: [
          Expanded(child: StatCard(
            label: 'Total Biaya Pengadaan',
            value: Formatters.currency(totalCost),
            icon: Icons.shopping_bag_rounded,
            accentColor: colorScheme.primary,
          )),
          const SizedBox(width: 16),
          Expanded(child: StatCard(
            label: 'Sudah Terbayar',
            value: Formatters.currency(totalPaid),
            icon: Icons.check_circle_rounded,
            accentColor: const Color(0xFF2ECC71),
            subtitle: '${((totalPaid/totalCost)*100).toStringAsFixed(1)}% Terlunasi',
          )),
          const SizedBox(width: 16),
          Expanded(child: StatCard(
            label: 'Sisa Hutang Aktif',
            value: Formatters.currency(totalCost - totalPaid),
            icon: Icons.assignment_late_rounded,
            accentColor: const Color(0xFFF1C40F),
            subtitle: '$unpaidCount Nota Belum Lunas',
          )),
        ],
      ),
    );
  }

  Widget _buildEntityGroupedList(List<Product> products, List<RestockRecord> restocks, bool isSupplier) {
    final Map<String, List<_BillRecord>> groups = {};

    void addRecord(String entity, String productName, double amount, double paid, DateTime date, bool isInitial, String id, bool isSupplierSide) {
      final rem = amount - paid;
      final isPaid = rem <= 0.5;

      if (_filter == 'unpaid' && isPaid) return;
      if (_filter == 'paid' && !isPaid) return;

      groups.putIfAbsent(entity, () => []).add(_BillRecord(
        id: id, productName: productName, amount: amount, paid: paid, date: date, isInitial: isInitial, isForSupplier: isSupplierSide
      ));
    }

    for (var p in products) {
      final f = p.financials;
      if (isSupplier) {
        if (f.supplierPaymentStatus != PaymentStatus.notApplicable) {
          addRecord(f.supplierName ?? 'Supplier Umum', p.name, f.supplierPrice, f.supplierPaidAmount, p.createdAt, true, p.id, true);
        }
      } else {
        if (f.shippingPaymentStatus != PaymentStatus.notApplicable) {
          addRecord(f.shippingServiceName ?? 'Ekspedisi Umum', p.name, f.supplierShippingCost, f.shippingPaidAmount, p.createdAt, true, p.id, false);
        }
      }
    }

    for (var r in restocks) {
      if (isSupplier) {
        if (r.supplierPaymentStatus != PaymentStatus.notApplicable) {
          addRecord(r.supplierName ?? 'Supplier Umum', r.productName, r.supplierPrice, r.supplierPaidAmount, r.createdAt, false, r.id, true);
        }
      } else {
        if (r.shippingPaymentStatus != PaymentStatus.notApplicable) {
          addRecord(r.shippingServiceName ?? 'Ekspedisi Umum', r.productName, r.shippingCost, r.shippingPaidAmount, r.createdAt, false, r.id, false);
        }
      }
    }

    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Tidak ada data tagihan',
        subtitle: 'Semua tagihan lunas atau belum ada input pengadaan',
      );
    }

    final sortedEntities = groups.keys.toList()..sort();
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sortedEntities.length,
      itemBuilder: (context, index) {
        final entity = sortedEntities[index];
        final records = groups[entity]!;
        final totalDue = records.fold<double>(0, (s, r) => s + r.amount);
        final totalPaid = records.fold<double>(0, (s, r) => s + r.paid);
        final totalRem = totalDue - totalPaid;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(isSupplier ? Icons.business_rounded : Icons.local_shipping_rounded, color: colorScheme.primary, size: 20),
              ),
              title: Text(entity, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text('${records.length} Batch Nota', style: const TextStyle(fontSize: 11)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _tileStat('Total Biaya', totalDue, colorScheme.onSurface),
                  const SizedBox(width: 16),
                  _tileStat('Terbayar', totalPaid, const Color(0xFF2ECC71)),
                  const SizedBox(width: 16),
                  _tileStat('Sisa Hutang', totalRem, colorScheme.primary, isBold: true),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down_rounded),
                ],
              ),
              children: [
                const Divider(height: 1),
                ...records.map((r) => _recordItem(r, entity)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tileStat(String label, double val, Color color, {bool isBold = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(fontSize: 8, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        Text(Formatters.currency(val), style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color)),
      ],
    );
  }

  Widget _recordItem(_BillRecord r, String entity) {
    final colorScheme = Theme.of(context).colorScheme;
    final rem = r.amount - r.paid;
    final isPaid = rem <= 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(r.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 8),
                    StatusChip(
                      label: r.isInitial ? 'Stok Awal' : 'Restock',
                      color: r.isInitial ? colorScheme.secondary : const Color(0xFF3498DB),
                    ),
                  ],
                ),
                Text('Batch: ${Formatters.dateTime(r.date)}', style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6))),
              ],
            ),
          ),
          _tileStat('Tagihan', r.amount, colorScheme.onSurface),
          const SizedBox(width: 24),
          _tileStat('Sisa', rem, colorScheme.primary, isBold: true),
          const SizedBox(width: 24),
          if (!isPaid)
            ElevatedButton(
              onPressed: () => _showPayDialog(r, entity),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(80, 36),
              ),
              child: const Text('BAYAR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            )
          else
            Icon(Icons.check_circle_rounded, color: const Color(0xFF2ECC71), size: 24),
        ],
      ),
    );
  }

  void _showPayDialog(_BillRecord item, String entityName) {
    showDialog(
      context: context,
      builder: (context) => _PayBillDialog(
        item: item,
        entityName: entityName,
      ),
    );
  }
}

class _BillRecord {
  final String id;
  final String productName;
  final double amount;
  final double paid;
  final DateTime date;
  final bool isInitial;
  final bool isForSupplier;
  _BillRecord({required this.id, required this.productName, required this.amount, required this.paid, required this.date, required this.isInitial, required this.isForSupplier});
}

class _PayBillDialog extends ConsumerStatefulWidget {
  final _BillRecord item;
  final String entityName;
  const _PayBillDialog({required this.item, required this.entityName});

  @override
  ConsumerState<_PayBillDialog> createState() => _PayBillDialogState();
}

class _PayBillDialogState extends ConsumerState<_PayBillDialog> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final rem = widget.item.amount - widget.item.paid;
    _amountCtrl.text = rem.toStringAsFixed(0);
  }

  Future<void> _submit() async {
    final amt = double.tryParse(_amountCtrl.text) ?? 0;
    if (amt <= 0) return;

    setState(() => _loading = true);
    try {
      final payment = BillPayment(
        id: const Uuid().v4(),
        billId: widget.item.id,
        entityName: widget.entityName,
        productName: widget.item.productName,
        amount: amt,
        status: PaymentStatus.paid,
        createdAt: DateTime.now(),
        isInitialBill: widget.item.isInitial,
        isForSupplier: widget.item.isForSupplier,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      await ref.read(billPaymentRepositoryProvider).savePayment(payment);
      
      if (mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Pembayaran berhasil dicatat');
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rem = widget.item.amount - widget.item.paid;
    return AlertDialog(
      title: const Text('Catat Pembayaran Tagihan'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Produk', widget.item.productName),
            _infoRow('Entitas', widget.entityName),
            _infoRow('Sisa Tagihan', Formatters.currency(rem)),
            const Divider(height: 32),
            TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Jumlah Bayar', prefixText: 'Rp '),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(controller: _notesCtrl, decoration: const InputDecoration(labelText: 'Catatan (Opsional)')),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const AppLoading() : const Text('SIMPAN PEMBAYARAN'),
        ),
      ],
    );
  }

  Widget _infoRow(String l, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        Text(v, style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}
