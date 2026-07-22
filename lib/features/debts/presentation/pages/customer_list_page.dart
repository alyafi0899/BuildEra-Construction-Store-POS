import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../models/customer.dart';
import '../../providers/debt_repository.dart';
import '../pages/customer_debt_detail_page.dart';
import '../../../../shared/widgets/security_gate.dart';

class CustomerListPage extends ConsumerStatefulWidget {
  const CustomerListPage({super.key});

  @override
  ConsumerState<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends ConsumerState<CustomerListPage> {
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
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          PageHeader(
            title: 'Pelanggan',
            subtitle: 'Daftar piutang dan profil',
            icon: Icons.people_rounded,
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: AppSearchField(
              controller: _searchCtrl,
              hintText: 'Cari nama atau telepon...',
              onChanged: (v) => setState(() => _search = v),
              onClear: () => setState(() { _search = ''; _searchCtrl.clear(); }),
            ),
          ),

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
                    subtitle: 'Tambah pelanggan baru menggunakan tombol +',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    return _CustomerCard(
                      customer: c,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CustomerDebtDetailPage(customer: c)),
                      ),
                      onEdit: () => requirePin(context, ref, () => _showCustomerForm(context, customer: c)),
                      onDelete: () => _deleteCustomer(c.id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCustomerForm(context),
        backgroundColor: AppTheme.primary,
        child: const Icon(Icons.person_add_rounded, color: Colors.white),
      ),
    );
  }

  void _showCustomerForm(BuildContext context, {Customer? customer}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.surface,
      builder: (context) => _CustomerFormSheet(customer: customer),
    );
  }

  Future<void> _deleteCustomer(String id) async {
    final ok = await showConfirmDialog(context,
        title: 'Hapus Pelanggan',
        content: 'Yakin hapus data pelanggan ini?');
    if (ok) {
      if (mounted) {
        requirePin(context, ref, () async {
          try {
            await ref.read(debtRepositoryProvider).deleteCustomer(id);
            if (mounted) showSuccess(context, 'Data pelanggan dihapus');
          } catch (e) {
            if (mounted) showError(context, e.toString());
          }
        });
      }
    }
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasDebt = customer.totalOutstanding > 0;
    
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppTheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(customer.phone, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.currency(customer.totalOutstanding),
                style: TextStyle(
                  color: hasDebt ? AppTheme.danger : AppTheme.success,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Text('Outstanding', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
          PopupMenuButton(
            icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppTheme.textMuted),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(value: 'delete', child: Text('Hapus', style: TextStyle(color: AppTheme.danger))),
            ],
            onSelected: (val) {
              if (val == 'edit') onEdit();
              if (val == 'delete') onDelete();
            },
          ),
        ],
      ),
    );
  }
}

class _CustomerFormSheet extends ConsumerStatefulWidget {
  final Customer? customer;
  const _CustomerFormSheet({this.customer});

  @override
  ConsumerState<_CustomerFormSheet> createState() => _CustomerFormSheetState();
}

class _CustomerFormSheetState extends ConsumerState<_CustomerFormSheet> {
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
        id: const Uuid().v4(),
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
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                Text(widget.customer == null ? 'Tambah Pelanggan' : 'Edit Pelanggan', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                      child: const Text('Simpan Data Pelanggan'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
