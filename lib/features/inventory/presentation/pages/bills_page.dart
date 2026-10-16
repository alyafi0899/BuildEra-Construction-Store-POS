import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/models/product_financials.dart';
import '../../../products/providers/product_provider.dart';
import '../../providers/restock_provider.dart';
import '../../models/restock_record.dart';
import '../../../../shared/models/product.dart';

import '../../../products/models/supplier.dart';
import '../../../products/models/shipping_service.dart';
import '../../../products/providers/entity_provider.dart';
import '../../models/bill_payment.dart';
import '../../providers/bill_payment_provider.dart';
import '../../../../shared/widgets/security_gate.dart';
import '../../../../features/settings/providers/settings_provider.dart';
import '../../../../shared/widgets/feature_tour_overlay.dart';

class BillsPage extends ConsumerStatefulWidget {
  const BillsPage({super.key});

  @override
  ConsumerState<BillsPage> createState() => _BillsPageState();
}

class _BillsPageState extends ConsumerState<BillsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: PinGate(
        manualTrigger: ref.watch(settingsProvider).lockInventoryPage,
        child: FeatureTourOverlay(
          tourKey: 'bills',
          steps: const [
            TourStep(
              title: 'Tagihan Operasional Toko',
              description: 'Pencatatan pengeluaran operasional toko seperti listrik, gaji karyawan, dan sewa tempat.',
              icon: Icons.receipt_rounded,
            ),
            TourStep(
              title: 'Tagihan Supplier & Ekspedisi',
              description: 'Pantau tagihan pembelian barang dari supplier dan biaya ongkos kirim ekspedisi yang belum lunas.',
              icon: Icons.local_shipping_rounded,
            ),
          ],
          child: Column(
            children: [
            const PageHeader(
            title: 'Manajemen Tagihan',
            subtitle: 'Pantau riwayat biaya dan kelola hutang operasional',
            icon: Icons.receipt_rounded,
          ),
          
          _buildQuickStats(productsAsync, restocksAsync),

          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.accent,
              labelColor: AppTheme.accent,
              unselectedLabelColor: AppTheme.textSecondary,
              tabs: const [
                Tab(text: 'Tagihan Supplier'),
                Tab(text: 'Tagihan Ekspedisi'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _BillsList(isSupplier: true, products: productsAsync, restocks: restocksAsync),
                _BillsList(isSupplier: false, products: productsAsync, restocks: restocksAsync),
              ],
            ),
          ),
        ],
      ),
    ),
    ),
  );
}

  Widget _buildQuickStats(AsyncValue<List<Product>> products, AsyncValue<List<RestockRecord>> restocks) {
    return products.when(
      data: (pList) => restocks.when(
        data: (rList) {
          double totalCost = 0;
          double totalPaid = 0;
          int pendingCount = 0;

          void process(double total, double paid, PaymentStatus status) {
            if (status == PaymentStatus.notApplicable) return;
            totalCost += total;
            totalPaid += paid;
            if (status != PaymentStatus.paid) pendingCount++;
          }

          for (final p in pList) {
            process(p.financials.supplierPrice, p.financials.supplierPaidAmount, p.financials.supplierPaymentStatus);
            process(p.financials.supplierShippingCost, p.financials.shippingPaidAmount, p.financials.shippingPaymentStatus);
          }
          for (final r in rList) {
            process(r.supplierPrice, r.supplierPaidAmount, r.supplierPaymentStatus);
            process(r.shippingCost, r.shippingPaidAmount, r.shippingPaymentStatus);
          }

          final totalRemaining = totalCost - totalPaid;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 700;
                final cards = [
                  StatCard(
                    label: 'Total Biaya Pengadaan',
                    value: Formatters.currency(totalCost),
                    icon: Icons.account_balance_wallet_rounded,
                    accentColor: AppTheme.info,
                    subtitle: 'Total Keseluruhan',
                  ),
                  StatCard(
                    label: 'Sudah Terbayar',
                    value: Formatters.currency(totalPaid),
                    icon: Icons.check_circle_outline_rounded,
                    accentColor: AppTheme.success,
                    subtitle:
                        '${totalCost > 0 ? ((totalPaid / totalCost) * 100).toStringAsFixed(1) : 0}% Terlunasi',
                  ),
                  StatCard(
                    label: 'Sisa Hutang Aktif',
                    value: Formatters.currency(totalRemaining),
                    icon: Icons.pending_actions_rounded,
                    accentColor: AppTheme.warning,
                    subtitle: '$pendingCount Nota Belum Lunas',
                  ),
                ];

                if (isCompact) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: cards
                          .map((card) => Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(width: 220, child: card),
                              ))
                          .toList(),
                    ),
                  );
                }

                return Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[1]),
                    const SizedBox(width: 16),
                    Expanded(child: cards[2]),
                  ],
                );
              },
            ),
          );
        },
        loading: () => const SizedBox(height: 100),
        error: (_, __) => const SizedBox(),
      ),
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _BillsList extends ConsumerStatefulWidget {
  final bool isSupplier;
  final AsyncValue<List<Product>> products;
  final AsyncValue<List<RestockRecord>> restocks;

  const _BillsList({required this.isSupplier, required this.products, required this.restocks});

  @override
  ConsumerState<_BillsList> createState() => _BillsListState();
}

class _BillsListState extends ConsumerState<_BillsList> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    return widget.products.when(
      data: (pList) => widget.restocks.when(
        data: (rList) {
          final bills = <_BillItem>[];

          void addIfMatch(String id, String name, String? entity, double total, double paid, PaymentStatus status, DateTime date, bool isInitial, dynamic original) {
            if (entity == null || entity.trim().isEmpty) return;

            bool matches = false;
            if (_filter == 'all') {
              matches = true;
            } else if (_filter == 'unpaid') {
              matches = (status == PaymentStatus.unpaid || status == PaymentStatus.partial);
            } else if (_filter == 'paid') {
              matches = (status == PaymentStatus.paid);
            }

            if (status == PaymentStatus.notApplicable) {
              // Only show N/A items when filter is 'all'
              matches = (_filter == 'all');
            }

            if (matches) {
              bills.add(_BillItem(
                id: id,
                name: name,
                entityName: entity,
                amount: total,
                paidAmount: paid,
                status: status,
                date: date,
                isInitial: isInitial,
                original: original,
              ));
            }
          }

          for (final p in pList) {
            final f = p.financials;
            if (widget.isSupplier) {
              addIfMatch(p.id, p.name, f.supplierName, f.supplierPrice, f.supplierPaidAmount, f.supplierPaymentStatus, p.createdAt, true, p);
            } else {
              addIfMatch(p.id, p.name, f.shippingServiceName, f.supplierShippingCost, f.shippingPaidAmount, f.shippingPaymentStatus, p.createdAt, true, p);
            }
          }

          for (final r in rList) {
            if (widget.isSupplier) {
              addIfMatch(r.id, r.productName, r.supplierName, r.supplierPrice, r.supplierPaidAmount, r.supplierPaymentStatus, r.createdAt, false, r);
            } else {
              addIfMatch(r.id, r.productName, r.shippingServiceName, r.shippingCost, r.shippingPaidAmount, r.shippingPaymentStatus, r.createdAt, false, r);
            }
          }

          bills.sort((a, b) => b.date.compareTo(a.date));

          return Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: bills.isEmpty 
                  ? const EmptyState(icon: Icons.receipt_long_rounded, title: 'Tidak ada data tagihan')
                  : _buildGroupedList(bills),
              ),
            ],
          );
        },
        loading: () => const AppLoading(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _filterChip('Belum Lunas', 'unpaid'),
          const SizedBox(width: 8),
          _filterChip('Sudah Lunas', 'paid'),
          const SizedBox(width: 8),
          _filterChip('Semua', 'all'),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => widget.isSupplier
                ? _showAddSupplier(context, ref)
                : _showAddShipping(context, ref),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: Text(
                'Tambah ${widget.isSupplier ? "Supplier" : "Ekspedisi"}',
                style: const TextStyle(fontSize: 11)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ]),
      ),
    );
  }

  void _showAddSupplier(BuildContext context, WidgetRef ref, {Supplier? supplier}) {
    final nameCtrl = TextEditingController(text: supplier?.name);
    final phoneCtrl = TextEditingController(text: supplier?.phone);
    final addrCtrl = TextEditingController(text: supplier?.address);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier == null ? 'Tambah Supplier' : 'Edit Supplier'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Perusahaan/Sales *', isDense: true),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor HP/WA', isDense: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Alamat', isDense: true),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final s = (supplier ?? Supplier(id: const Uuid().v4(), name: '', createdAt: DateTime.now())).copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                );
                await ref.read(entityRepositoryProvider).saveSupplier(s);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showAddShipping(BuildContext context, WidgetRef ref, {ShippingService? shipping}) {
    final nameCtrl = TextEditingController(text: shipping?.name);
    final phoneCtrl = TextEditingController(text: shipping?.phone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(shipping == null ? 'Tambah Ekspedisi' : 'Edit Ekspedisi'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: Map<String, dynamic>.from({}).isEmpty ? MainAxisSize.min : MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Ekspedisi/Supir *', isDense: true),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor HP/WA', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final s = (shipping ?? ShippingService(id: const Uuid().v4(), name: '', createdAt: DateTime.now())).copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                );
                await ref.read(entityRepositoryProvider).saveShippingService(s);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final active = _filter == value;
    return InkWell(
      onTap: () => setState(() => _filter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppTheme.accent.withValues(alpha: 0.15) : AppTheme.surfaceAlt,
          border: Border.all(color: active ? AppTheme.accent : AppTheme.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, 
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? AppTheme.accent : AppTheme.textSecondary,
        )),
      ),
    );
  }

  Widget _buildGroupedList(List<_BillItem> bills) {
    final grouped = groupBy(bills, (b) => b.entityName);
    final entities = grouped.keys.toList()..sort();
    
    final suppliers = ref.watch(suppliersProvider).asData?.value ?? [];
    final shippings = ref.watch(shippingServicesProvider).asData?.value ?? [];

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: entities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final entityName = entities[i];
        final items = grouped[entityName]!;
        final totalBill = items.fold<double>(0, (s, item) => s + item.amount);
        final totalPaid = items.fold<double>(0, (s, item) => s + item.paidAmount);
        final totalRemaining = totalBill - totalPaid;

        dynamic entityObj;
        if (widget.isSupplier) {
          entityObj = suppliers.firstWhereOrNull((s) => s.name == entityName);
        } else {
          entityObj = shippings.firstWhereOrNull((s) => s.name == entityName);
        }

        return _EntityExpandableGroup(
          entityName: entityName,
          isSupplier: widget.isSupplier,
          totalBill: totalBill,
          totalPaid: totalPaid,
          totalRemaining: totalRemaining,
          items: items,
          entity: entityObj,
        );
      },
    );
  }
}

class _EntityExpandableGroup extends ConsumerStatefulWidget {
  final String entityName;
  final bool isSupplier;
  final double totalBill;
  final double totalPaid;
  final double totalRemaining;
  final List<_BillItem> items;
  final dynamic entity;

  const _EntityExpandableGroup({
    required this.entityName,
    required this.isSupplier,
    required this.totalBill,
    required this.totalPaid,
    required this.totalRemaining,
    required this.items,
    this.entity,
  });

  @override
  ConsumerState<_EntityExpandableGroup> createState() => _EntityExpandableGroupState();
}

class _EntityExpandableGroupState extends ConsumerState<_EntityExpandableGroup> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    String? contact;
    if (widget.entity is Supplier) contact = (widget.entity as Supplier).phone;
    if (widget.entity is ShippingService) contact = (widget.entity as ShippingService).phone;

    return Column(
      children: [
        Material(
          color: AppTheme.surfaceAlt,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _isExpanded ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.border),
          ),
          child: InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.isSupplier ? AppTheme.accent : AppTheme.info, 
                    borderRadius: BorderRadius.circular(8)
                  ),
                  child: Icon(
                    widget.isSupplier ? Icons.business_rounded : Icons.local_shipping_rounded, 
                    size: 20, color: Colors.white
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.entityName.toUpperCase(), 
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                      if (contact != null)
                        Text('Hubungi: $contact', style: const TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold))
                      else
                        Text('${widget.items.length} Batch Nota', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                _summarySmallItem('Total Biaya', widget.totalBill, AppTheme.textPrimary),
                const SizedBox(width: 20),
                _summarySmallItem('Terbayar', widget.totalPaid, AppTheme.success),
                const SizedBox(width: 20),
                _summarySmallItem('Sisa Hutang', widget.totalRemaining, AppTheme.warning),
                const SizedBox(width: 20),
                
                // --- Action Buttons and Dropdown at the far right ---
                if (widget.entity != null) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.info),
                    onPressed: () => widget.isSupplier 
                        ? _showEditSupplier(context, (widget.entity as Supplier))
                        : _showEditShipping(context, (widget.entity as ShippingService)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Edit Data',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                    onPressed: () => _handleDelete(context, widget.entityName),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Hapus Data',
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, 
                  color: AppTheme.textMuted
                ),
              ]),
            ),
          ),
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 12),
            child: Column(
              children: widget.items.map((item) => _BillTile(item: item, isSupplier: widget.isSupplier)).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _handleDelete(BuildContext context, String name) async {
    final ok = await showConfirmDialog(context, 
      title: 'Hapus Data Master', 
      content: 'Yakin hapus data "$name"? Menghapus data ini juga akan membersihkan nama ${widget.isSupplier ? "supplier" : "ekspedisi"} di seluruh histori tagihan.');
    
    if (ok) {
      if (widget.isSupplier) {
        final id = (widget.entity as Supplier).id;
        await ref.read(entityRepositoryProvider).deleteSupplierCompletely(id, name);
      } else {
        final id = (widget.entity as ShippingService).id;
        await ref.read(entityRepositoryProvider).deleteShippingServiceCompletely(id, name);
      }
      if (context.mounted) showSuccess(context, 'Data berhasil dihapus secara komplit');
    }
  }

  void _showEditSupplier(BuildContext context, Supplier supplier) {
    final nameCtrl = TextEditingController(text: supplier.name);
    final phoneCtrl = TextEditingController(text: supplier.phone);
    final addrCtrl = TextEditingController(text: supplier.address);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Supplier'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Perusahaan/Sales *', isDense: true),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor HP/WA', isDense: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Alamat', isDense: true),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final s = supplier.copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                );
                await ref.read(entityRepositoryProvider).saveSupplier(s);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showEditShipping(BuildContext context, ShippingService shipping) {
    final nameCtrl = TextEditingController(text: shipping.name);
    final phoneCtrl = TextEditingController(text: shipping.phone);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Ekspedisi'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Ekspedisi/Supir *', isDense: true),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor HP/WA', isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final s = shipping.copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                );
                await ref.read(entityRepositoryProvider).saveShippingService(s);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _summarySmallItem(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
        Text(Formatters.currency(value), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
      ],
    );
  }
}

class _BillItem {
  final String id;
  final String name;
  final String entityName;
  final double amount;
  final double paidAmount;
  final PaymentStatus status;
  final DateTime date;
  final bool isInitial;
  final dynamic original;

  _BillItem({
    required this.id, 
    required this.name, 
    required this.entityName, 
    required this.amount, 
    required this.paidAmount,
    required this.status,
    required this.date, 
    required this.isInitial,
    required this.original,
  });
}

class _BillTile extends ConsumerWidget {
  final _BillItem item;
  final bool isSupplier;
  const _BillTile({required this.item, required this.isSupplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = item.amount - item.paidAmount;
    final isPaid = item.status == PaymentStatus.paid;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPaid ? AppTheme.success.withValues(alpha: 0.2) : AppTheme.border),
      ),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    if (item.isInitial) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('Stok Awal', style: TextStyle(fontSize: 9, color: AppTheme.accent, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ]),
                  Text('Batch: ${Formatters.dateTime(item.date)}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Formatters.currency(item.amount), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(isPaid ? 'LUNAS' : 'Sisa: ${Formatters.currency(remaining)}', 
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.w900, 
                    color: isPaid ? AppTheme.success : AppTheme.warning,
                  )),
              ],
            ),
            const SizedBox(width: 16),
            if (!isPaid)
              ElevatedButton(
                onPressed: () => _showPaymentDialog(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
                child: const Text('BAYAR', style: TextStyle(fontSize: 11)),
              )
            else
              const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
          ]),
          
          _buildPaymentHistory(context, ref),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(billPaymentsProvider);
    
    return paymentsAsync.when(
      data: (allPayments) {
        final itemPayments = allPayments.where((p) => p.billId == item.id && p.isForSupplier == isSupplier).toList();
        if (itemPayments.isEmpty && item.paidAmount == 0) return const SizedBox();

        return Column(
          children: [
            const Divider(height: 24),
            Row(children: [
              const Icon(Icons.history_rounded, size: 12, color: AppTheme.textMuted),
              const SizedBox(width: 6),
              Text('Riwayat Pembayaran:', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
              const Spacer(),
              LinearProgressIndicator(
                value: item.amount > 0 ? (item.paidAmount / item.amount) : 0,
                backgroundColor: AppTheme.bg,
                valueColor: const AlwaysStoppedAnimation(AppTheme.success),
                minHeight: 4,
              ).constrained(width: 80),
            ]),
            const SizedBox(height: 12),
            ...itemPayments.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Text(Formatters.dateTime(p.createdAt), style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                const SizedBox(width: 12),
                Expanded(child: Text(p.notes ?? 'Cicilan Pembayaran', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500))),
                Text(Formatters.currency(p.amount), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.success)),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () async {
                    final ok = await showConfirmDialog(context, title: 'Hapus Pembayaran', content: 'Hapus catatan pembayaran ini? Sisa hutang akan bertambah kembali.');
                    if (ok) {
                      await ref.read(billPaymentRepositoryProvider).deletePayment(p);
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.danger),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            )),
            if (itemPayments.isEmpty && item.paidAmount > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text('Data pembayaran lama (sebelum update riwayat)', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.textMuted)),
              ),
          ],
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    final remaining = item.amount - item.paidAmount;
    final amountCtrl = TextEditingController(text: Formatters.decimal(remaining));
    final notesCtrl = TextEditingController();

    Future<void> submit() async {
      final val = Formatters.parseDecimal(amountCtrl.text);
      if (val <= 0) return;

      final payment = BillPayment(
        id: const Uuid().v4(),
        billId: item.id,
        amount: val,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        createdAt: DateTime.now(),
        isInitialBill: item.isInitial,
        isForSupplier: isSupplier,
      );

      await ref.read(billPaymentRepositoryProvider).savePayment(payment);

      if (context.mounted) {
        Navigator.pop(context);
        showSuccess(context, 'Pembayaran berhasil dicatat');
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Input Pembayaran Tagihan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tagihan: ${item.name}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Sisa Hutang: ${Formatters.currency(remaining)}',
                style: const TextStyle(fontSize: 12, color: AppTheme.warning)),
            const SizedBox(height: 20),
            TextFormField(
              controller: amountCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Jumlah Bayar (Rp) *',
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              onFieldSubmitted: (_) => submit(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Keterangan / Catatan',
                hintText: 'Contoh: Titip ke Supir, Transfer Bank, dll',
              ),
              onFieldSubmitted: (_) => submit(),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => submit(),
            child: const Text('Simpan Pembayaran'),
          ),
        ],
      ),
    );
  }
}

Map<K, List<V>> groupBy<V, K>(Iterable<V> values, K Function(V) key) {
  var map = <K, List<V>>{};
  for (var element in values) {
    (map[key(element)] ??= []).add(element);
  }
  return map;
}

extension on Widget {
  Widget constrained({double? width, double? height}) => SizedBox(width: width, height: height, child: this);
}
