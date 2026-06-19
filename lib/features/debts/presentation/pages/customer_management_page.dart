import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../models/customer.dart';
import '../../providers/debt_repository.dart';

class CustomerManagementPage extends ConsumerStatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  ConsumerState<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends ConsumerState<CustomerManagementPage> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.surface,
            child: Row(
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Data Pelanggan', style: Theme.of(context).textTheme.headlineLarge),
                  Text('Kelola profil pelanggan untuk transaksi piutang', style: Theme.of(context).textTheme.bodyMedium),
                ]),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showCustomerForm(context),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Tambah Pelanggan'),
                ),
              ],
            ),
          ),

          // Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: AppTheme.surface,
            child: Row(
              children: [
                SizedBox(
                  width: 300,
                  child: AppSearchField(
                    controller: _searchCtrl,
                    hintText: 'Cari nama atau nomor telepon...',
                    onChanged: (v) => setState(() => _search = v),
                    onClear: () => setState(() { _search = ''; _searchCtrl.clear(); }),
                  ),
                ),
              ],
            ),
          ),

          // Table
          Expanded(
            child: customersAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (customers) {
                final filtered = customers.where((c) {
                  final q = _search.toLowerCase();
                  return c.name.toLowerCase().contains(q) || c.phone.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'Tidak ada pelanggan',
                    subtitle: 'Mulai dengan menambahkan pelanggan baru',
                  );
                }

                return _CustomerTable(
                  customers: filtered,
                  onEdit: (c) => _showCustomerForm(context, customer: c),
                  onDelete: (id) => _deleteCustomer(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCustomerForm(BuildContext context, {Customer? customer}) {
    showDialog(
      context: context,
      builder: (context) => _CustomerFormDialog(customer: customer),
    );
  }

  Future<void> _deleteCustomer(String id) async {
    final ok = await showConfirmDialog(context,
        title: 'Hapus Pelanggan',
        content: 'Yakin hapus data pelanggan ini?');
    if (ok) {
      try {
        await ref.read(debtRepositoryProvider).deleteCustomer(id);
        if (mounted) showSuccess(context, 'Data pelanggan dihapus');
      } catch (e) {
        if (mounted) showError(context, e.toString());
      }
    }
  }
}

class _CustomerTable extends StatelessWidget {
  final List<Customer> customers;
  final Function(Customer) onEdit;
  final Function(String) onDelete;

  const _CustomerTable({
    required this.customers,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      child: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: customers.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = customers[i];
          return _CustomerRow(
            customer: c,
            onEdit: () => onEdit(c),
            onDelete: () => onDelete(c.id),
          );
        },
      ),
    );
  }
}

class _CustomerRow extends StatelessWidget {
  final Customer customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerRow({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppTheme.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, style: Theme.of(context).textTheme.titleLarge),
                Text(customer.phone, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Total Piutang', style: Theme.of(context).textTheme.bodySmall),
              Text(
                Formatters.currency(customer.totalOutstanding),
                style: TextStyle(
                  color: customer.totalOutstanding > 0 ? AppTheme.warning : AppTheme.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.textSecondary),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_rounded, size: 20, color: AppTheme.danger),
            tooltip: 'Hapus',
          ),
        ],
      ),
    );
  }
}

class _CustomerFormDialog extends ConsumerStatefulWidget {
  final Customer? customer;
  const _CustomerFormDialog({this.customer});

  @override
  ConsumerState<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<_CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customer?.name);
    _phoneCtrl = TextEditingController(text: widget.customer?.phone);
    _addressCtrl = TextEditingController(text: widget.customer?.address);
    _notesCtrl = TextEditingController(text: widget.customer?.notes);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      final customer = (widget.customer ?? Customer(
        id: Uuid().v4(),
        name: '',
        phone: '',
        createdAt: DateTime.now(),
      )).copyWith(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      try {
        await ref.read(debtRepositoryProvider).saveCustomer(customer);
        if (mounted) {
          Navigator.pop(context);
          showSuccess(context, 'Data pelanggan disimpan');
        }
      } catch (e) {
        if (mounted) showError(context, 'Gagal menyimpan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.customer == null ? 'Tambah Pelanggan' : 'Edit Pelanggan'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap *'),
                validator: (v) => v!.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor Telepon *'),
                validator: (v) => v!.isEmpty ? 'Nomor telepon tidak boleh kosong' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Alamat'),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Catatan'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(onPressed: _save, child: const Text('Simpan')),
      ],
    );
  }
}
