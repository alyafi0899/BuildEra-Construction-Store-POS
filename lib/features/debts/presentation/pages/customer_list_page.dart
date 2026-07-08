import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:buildera/shared/widgets/common_widgets.dart';
import 'package:buildera/features/debts/providers/debt_repository.dart';
import 'package:buildera/features/debts/models/customer.dart';
import 'customer_debt_detail_page.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          PageHeader(
            title: 'Daftar Pelanggan',
            subtitle: 'Kelola data dan riwayat hutang pelanggan',
            icon: Icons.people_rounded,
            actions: [
              ElevatedButton.icon(
                onPressed: () => _showAddCustomer(context),
                icon: const Icon(Icons.person_add_rounded),
                label: const Text('Pelanggan Baru'),
              ),
            ],
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outline)),
            ),
            child: Row(children: [
              SizedBox(
                width: 400,
                child: AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'Cari nama atau nomor telepon...',
                  onChanged: (v) => setState(() => _search = v),
                  onClear: () => setState(() {
                    _search = '';
                    _searchCtrl.clear();
                  }),
                ),
              ),
            ]),
          ),

          Expanded(
            child: customersAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                final filtered = list.where((c) => 
                  c.name.toLowerCase().contains(_search.toLowerCase()) || 
                  c.phone.contains(_search)
                ).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.people_outline_rounded, title: 'Belum ada pelanggan');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _CustomerRow(customer: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomer(BuildContext context, {Customer? customer}) async {
    final nameCtrl = TextEditingController(text: customer?.name);
    final phoneCtrl = TextEditingController(text: customer?.phone);
    final addressCtrl = TextEditingController(text: customer?.address);
    final notesCtrl = TextEditingController(text: customer?.notes);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer == null ? 'Tambah Pelanggan' : 'Edit Pelanggan'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Lengkap *')),
              const SizedBox(height: 16),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Nomor Telepon *'), keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Alamat'), maxLines: 2),
              const SizedBox(height: 16),
              TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Catatan'), maxLines: 2),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                showError(ctx, 'Nama dan Nomor Telepon wajib diisi');
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final c = (customer ?? Customer(id: '', name: '', phone: '', createdAt: DateTime.now())).copyWith(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        address: addressCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
      );
      if (customer == null) {
        final newC = Customer(
          id: const Uuid().v4(),
          name: c.name, phone: c.phone, address: c.address, notes: c.notes,
          createdAt: DateTime.now(),
        );
        await ref.read(debtRepositoryProvider).saveCustomer(newC);
      } else {
        await ref.read(debtRepositoryProvider).saveCustomer(c);
      }
      if (mounted) showSuccess(context, 'Data pelanggan disimpan');
    }
  }
}

class _CustomerRow extends ConsumerWidget {
  final Customer customer;
  const _CustomerRow({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person_rounded, color: colorScheme.primary),
          ),
          title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(customer.phone, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => CustomerDebtDetailPage(customer: customer),
            ));
          },
        ),
      ),
    );
  }
}
