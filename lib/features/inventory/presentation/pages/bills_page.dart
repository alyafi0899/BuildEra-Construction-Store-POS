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
      body: Column(
        children: [
          const PageHeader(
            title: 'Tagihan',
            subtitle: 'Kelola hutang ke supplier',
            icon: Icons.receipt_rounded,
          ),
          
          Container(
            color: AppTheme.surface,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Supplier'),
                Tab(text: 'Ekspedisi'),
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
  String _filter = 'unpaid';

  @override
  Widget build(BuildContext context) {
    return widget.products.when(
      data: (pList) => widget.restocks.when(
        data: (rList) {
          final bills = <_BillItem>[];

          void addIfMatch(String id, String name, String? entity, double total, double paid, PaymentStatus status, DateTime date, bool isInitial, dynamic original) {
            bool matches = false;
            if (_filter == 'all') matches = true;
            else if (_filter == 'unpaid') matches = (status == PaymentStatus.unpaid || status == PaymentStatus.partial);
            else if (_filter == 'paid') matches = (status == PaymentStatus.paid);

            if (status != PaymentStatus.notApplicable && matches) {
              bills.add(_BillItem(
                id: id,
                name: name,
                entityName: entity ?? 'Umum',
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
            if (widget.isSupplier) addIfMatch(p.id, p.name, f.supplierName, f.supplierPrice, f.supplierPaidAmount, f.supplierPaymentStatus, p.createdAt, true, p);
            else addIfMatch(p.id, p.name, f.shippingServiceName, f.supplierShippingCost, f.shippingPaidAmount, f.shippingPaymentStatus, p.createdAt, true, p);
          }

          for (final r in rList) {
            if (widget.isSupplier) addIfMatch(r.id, r.productName, r.supplierName, r.supplierPrice, r.supplierPaidAmount, r.supplierPaymentStatus, r.createdAt, false, r);
            else addIfMatch(r.id, r.productName, r.shippingServiceName, r.shippingCost, r.shippingPaidAmount, r.shippingPaymentStatus, r.createdAt, false, r);
          }

          bills.sort((a, b) => b.date.compareTo(a.date));

          return Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: bills.isEmpty 
                  ? const EmptyState(icon: Icons.receipt_long_rounded, title: 'Tidak ada tagihan')
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        _filterChoice('Belum Lunas', 'unpaid'),
        const SizedBox(width: 8),
        _filterChoice('Lunas', 'paid'),
        const SizedBox(width: 8),
        _filterChoice('Semua', 'all'),
      ]),
    );
  }

  Widget _filterChoice(String label, String value) {
    final active = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: active ? AppTheme.primary : AppTheme.textSecondary,
        fontWeight: active ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildGroupedList(List<_BillItem> bills) {
    final grouped = groupBy(bills, (b) => b.entityName);
    final entities = grouped.keys.toList()..sort();
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: entities.length,
      itemBuilder: (context, i) {
        final entityName = entities[i];
        final items = grouped[entityName]!;
        final totalRemaining = items.fold<double>(0, (s, item) => s + (item.amount - item.paidAmount));

        return AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          onTap: () => _showEntityBills(context, entityName, items),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (widget.isSupplier ? AppTheme.primary : AppTheme.info).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.isSupplier ? Icons.business_rounded : Icons.local_shipping_rounded, 
                  color: widget.isSupplier ? AppTheme.primary : AppTheme.info, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entityName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${items.length} Nota', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Formatters.currency(totalRemaining), 
                    style: TextStyle(fontWeight: FontWeight.bold, color: totalRemaining > 0 ? AppTheme.danger : AppTheme.success)),
                  const Text('Sisa Hutang', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                ],
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
            ],
          ),
        );
      },
    );
  }

  void _showEntityBills(BuildContext context, String entityName, List<_BillItem> items) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (_) => _EntityBillsSheet(
        entityName: entityName,
        items: items,
        isSupplier: widget.isSupplier,
      ),
    );
  }
}

class _EntityBillsSheet extends StatelessWidget {
  final String entityName;
  final List<_BillItem> items;
  final bool isSupplier;

  const _EntityBillsSheet({required this.entityName, required this.items, required this.isSupplier});

  @override
  Widget build(BuildContext context) {
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
              Text(entityName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) => _BillDetailCard(item: items[i], isSupplier: isSupplier),
          ),
        ),
      ],
    );
  }
}

class _BillDetailCard extends ConsumerWidget {
  final _BillItem item;
  final bool isSupplier;
  const _BillDetailCard({required this.item, required this.isSupplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = item.amount - item.paidAmount;
    final isPaid = item.status == PaymentStatus.paid;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(Formatters.dateTime(item.date), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Formatters.currency(item.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(isPaid ? 'LUNAS' : 'Sisa: ${Formatters.currency(remaining)}', 
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isPaid ? AppTheme.success : AppTheme.danger)),
                ],
              ),
            ],
          ),
          if (!isPaid) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _showPaymentDialog(context, ref),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
              child: const Text('Input Pembayaran'),
            ),
          ],
        ],
      ),
    );
  }

  void _showPaymentDialog(BuildContext context, WidgetRef ref) {
    final amountCtrl = TextEditingController(text: (item.amount - item.paidAmount).toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bayar Tagihan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Jumlah Bayar', prefixText: 'Rp '),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final val = double.tryParse(amountCtrl.text) ?? 0;
              if (val <= 0) return;
              await ref.read(billPaymentRepositoryProvider).savePayment(BillPayment(
                id: const Uuid().v4(),
                billId: item.id,
                amount: val,
                createdAt: DateTime.now(),
                isInitialBill: item.isInitial,
                isForSupplier: isSupplier,
              ));
              if (context.mounted) {
                Navigator.pop(context);
                showSuccess(context, 'Pembayaran dicatat');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
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

Map<K, List<V>> groupBy<V, K>(Iterable<V> values, K Function(V) key) {
  var map = <K, List<V>>{};
  for (var element in values) {
    (map[key(element)] ??= []).add(element);
  }
  return map;
}
