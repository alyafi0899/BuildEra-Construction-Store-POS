import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/settings_provider.dart';
import '../../models/store_settings.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _businessNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _descriptionCtrl;

  List<BankAccount> _bankAccounts = [];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _businessNameCtrl = TextEditingController(text: settings.businessName);
    _ownerNameCtrl = TextEditingController(text: settings.ownerName);
    _phoneCtrl = TextEditingController(text: settings.phone);
    _emailCtrl = TextEditingController(text: settings.email);
    _addressCtrl = TextEditingController(text: settings.address);
    _descriptionCtrl = TextEditingController(text: settings.description);
    _bankAccounts = List.from(settings.bankAccounts);
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _addBankAccount() {
    setState(() {
      _bankAccounts.add(const BankAccount(bankName: '', accountNumber: '', accountHolder: ''));
    });
  }

  void _removeBankAccount(int index) {
    setState(() {
      _bankAccounts.removeAt(index);
    });
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final settings = ref.read(settingsProvider).copyWith(
        businessName: _businessNameCtrl.text,
        ownerName: _ownerNameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        address: _addressCtrl.text,
        description: _descriptionCtrl.text,
        bankAccounts: _bankAccounts,
      );
      
      ref.read(settingsProvider.notifier).updateSettings(settings);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan berhasil disimpan'),
          backgroundColor: AppTheme.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (prev, next) {
      if (_businessNameCtrl.text.isEmpty && next.businessName.isNotEmpty) {
        _businessNameCtrl.text = next.businessName;
        _ownerNameCtrl.text = next.ownerName;
        _phoneCtrl.text = next.phone;
        _emailCtrl.text = next.email;
        _addressCtrl.text = next.address;
        _descriptionCtrl.text = next.description;
        setState(() {
          _bankAccounts = List.from(next.bankAccounts);
        });
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            color: AppTheme.surface,
            child: Row(
              children: [
                const Icon(Icons.settings_rounded, color: AppTheme.accent, size: 24),
                const SizedBox(width: 12),
                Text('Pengaturan Toko', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Simpan Perubahan'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionTitle(title: 'Informasi Bisnis'),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildInput('Nama Bisnis', _businessNameCtrl, Icons.store_rounded)),
                            const SizedBox(width: 20),
                            Expanded(child: _buildInput('Nama Pemilik', _ownerNameCtrl, Icons.person_rounded)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _buildInput('Nomor Telepon', _phoneCtrl, Icons.phone_rounded)),
                            const SizedBox(width: 20),
                            Expanded(child: _buildInput('Email', _emailCtrl, Icons.email_rounded)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInput('Alamat', _addressCtrl, Icons.location_on_rounded, maxLines: 2),
                        const SizedBox(height: 20),
                        _buildInput('Deskripsi Toko', _descriptionCtrl, Icons.description_rounded, maxLines: 3),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            const _SectionTitle(title: 'Daftar Rekening Bank'),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _addBankAccount,
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: const Text('Tambah Rekening'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Column(
                          children: [
                            if (_bankAccounts.isEmpty)
                              const Center(child: Text('Belum ada rekening', style: TextStyle(color: AppTheme.textSecondary)))
                            else
                              for (int i = 0; i < _bankAccounts.length; i++)
                                _buildBankCard(i),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20, color: AppTheme.accent.withValues(alpha: 0.7)),
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildBankCard(int i) {
    final account = _bankAccounts[i];
    return Container(
      key: ValueKey('bank_card_$i'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSmallInput('Nama Bank', account.bankName, (v) {
                  setState(() => _bankAccounts[i] = BankAccount(bankName: v, accountNumber: account.accountNumber, accountHolder: account.accountHolder));
                }),
              ),
              IconButton(onPressed: () => _removeBankAccount(i), icon: const Icon(Icons.delete_outline, color: AppTheme.danger)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallInput('Nomor Rekening', account.accountNumber, (v) {
                  setState(() => _bankAccounts[i] = BankAccount(bankName: account.bankName, accountNumber: v, accountHolder: account.accountHolder));
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallInput('Pemilik', account.accountHolder, (v) {
                  setState(() => _bankAccounts[i] = BankAccount(bankName: account.bankName, accountNumber: account.accountNumber, accountHolder: v));
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInput(String label, String initial, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initial,
          onChanged: onChanged,
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.accent, fontWeight: FontWeight.bold)),
        const Divider(color: AppTheme.border, height: 24),
      ],
    );
  }
}
