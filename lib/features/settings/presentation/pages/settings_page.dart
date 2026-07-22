import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../providers/settings_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../models/store_settings.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../shared/widgets/common_widgets.dart';

import '../../../inventory/providers/restock_provider.dart';
import '../../../inventory/providers/bill_payment_provider.dart';
import '../../../debts/providers/debt_repository.dart';
import '../../../payment/providers/transaction_provider.dart';
import '../../../products/providers/product_provider.dart';
import '../../../../core/utils/backup_helper.dart';

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

  void _save() {
    if (_formKey.currentState!.validate()) {
      final settings = ref.read(settingsProvider).copyWith(
        businessName: _businessNameCtrl.text,
        ownerName: _ownerNameCtrl.text,
        phone: _phoneCtrl.text,
        email: _emailCtrl.text,
        address: _addressCtrl.text,
        description: _descriptionCtrl.text,
      );
      ref.read(settingsProvider.notifier).updateSettings(settings);
      showSuccess(context, 'Pengaturan disimpan');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          PageHeader(
            title: 'Pengaturan',
            subtitle: 'Konfigurasi toko dan sistem',
            icon: Icons.settings_rounded,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildGroup('TOKO', [
                  _tile(Icons.store_rounded, 'Informasi Bisnis', () => _showBusinessInfo(context)),
                  _tile(Icons.qr_code_2_rounded, 'Pengaturan QRIS', () => _showQrisSetting(context)),
                  _tile(Icons.account_balance_rounded, 'Rekening Bank', () => _showBankAccounts(context)),
                ]),
                const SizedBox(height: 16),
                _buildGroup('SISTEM', [
                  _tile(Icons.security_rounded, 'Keamanan & PIN', () => _showSecuritySetting(context)),
                  _tile(Icons.cloud_download_rounded, 'Backup Data', () => _handleFullBackup(context, ref)),
                  _tile(Icons.monitor_rounded, 'Tampilan Layar', () => _showDisplaySettings(context)),
                ]),
                const SizedBox(height: 16),
                _buildGroup('AKUN', [
                  _tile(Icons.logout_rounded, 'Keluar (Logout)', () => _handleLogout(context, ref), color: AppTheme.danger),
                ]),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textMuted)),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppTheme.primary, size: 22),
      title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: color)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
      onTap: onTap,
    );
  }

  void _showBusinessInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (_) => _SettingsFormSheet(
        title: 'Informasi Bisnis',
        onSave: _save,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _field(_businessNameCtrl, 'Nama Toko'),
              const SizedBox(height: 16),
              _field(_ownerNameCtrl, 'Nama Pemilik'),
              const SizedBox(height: 16),
              _field(_phoneCtrl, 'No. Telepon', keyboardType: TextInputType.phone),
              const SizedBox(height: 16),
              _field(_emailCtrl, 'Email', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _field(_addressCtrl, 'Alamat', maxLines: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }

  void _showQrisSetting(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider);
        return _SettingsFormSheet(
          title: 'Pengaturan QRIS',
          onSave: () => Navigator.pop(context),
          child: Column(
            children: [
              Container(
                height: 250, width: 180,
                decoration: BoxDecoration(color: AppTheme.surfaceAlt, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                child: settings.qrisImagePath != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(File(settings.qrisImagePath!), fit: BoxFit.cover))
                  : const Icon(Icons.qr_code_scanner_rounded, size: 64, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  final bytes = await ImageHelper.pickAndCropImage(context);
                  if (bytes != null) {
                    final user = ref.read(authStateProvider).value;
                    if (user == null) return;
                    final processed = await ImageHelper.processImage(bytes);
                    final path = await ImageHelper.saveLocally(user.uid, 'qris_barcode.jpg', processed, subFolder: 'store_assets');
                    if (path != null) {
                      ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(qrisImagePath: path));
                      if (mounted) showSuccess(context, 'QRIS diperbarui');
                    }
                  }
                },
                icon: const Icon(Icons.upload_rounded),
                label: const Text('Ganti Gambar QRIS'),
              ),
              if (settings.qrisImagePath != null)
                TextButton(
                  onPressed: () => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(qrisImagePath: null)),
                  child: const Text('Hapus Gambar', style: TextStyle(color: AppTheme.danger)),
                ),
            ],
          ),
        );
      }),
    );
  }

  void _showBankAccounts(BuildContext context) {
    // Similar implementation for bank accounts as a mobile-friendly list
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (_) => const _BankAccountsSheet(),
    );
  }

  void _showSecuritySetting(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (_) => const _SecuritySheet(),
    );
  }

  void _showDisplaySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg,
      builder: (_) => const _DisplaySettingsSheet(),
    );
  }

  Future<void> _handleFullBackup(BuildContext context, WidgetRef ref) async {
    showSuccess(context, 'Memulai proses backup...');
    try {
      await BackupHelper.performFullBackup(
        context: context,
        products: ref.read(productsProvider).asData?.value ?? [],
        restocks: ref.read(restockHistoryProvider).asData?.value ?? [],
        billPayments: ref.read(billPaymentsProvider).asData?.value ?? [],
        customers: ref.read(customersProvider).asData?.value ?? [],
        customerDebts: ref.read(debtsProvider(null)).asData?.value ?? [],
        customerPayments: ref.read(debtPaymentsProvider((customerId: null, debtId: null))).asData?.value ?? [],
        transactions: ref.read(transactionsProvider).asData?.value ?? [],
        settings: ref.read(settingsProvider),
      );
      if (mounted) showSuccess(context, 'Backup Berhasil!');
    } catch (e) {
      if (mounted) showError(context, 'Gagal: $e');
    }
  }

  void _handleLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showConfirmDialog(context, title: 'Keluar', content: 'Anda akan keluar dari akun ini.');
    if (ok) ref.read(authRepositoryProvider).logout();
  }
}

class _SettingsFormSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onSave;

  const _SettingsFormSheet({required this.title, required this.child, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 5, width: 40, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(5))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          const Divider(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  child,
                  const SizedBox(height: 32),
                  ElevatedButton(onPressed: onSave, child: const Text('Simpan Perubahan')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankAccountsSheet extends ConsumerStatefulWidget {
  const _BankAccountsSheet();
  @override
  ConsumerState<_BankAccountsSheet> createState() => _BankAccountsSheetState();
}

class _BankAccountsSheetState extends ConsumerState<_BankAccountsSheet> {
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final bankAccounts = settings.bankAccounts;

    return Column(
      children: [
        Container(height: 5, width: 40, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            const Text('Rekening Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Spacer(),
            IconButton(onPressed: () => _add(context, ref), icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary)),
            IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        const Divider(),
        Expanded(
          child: bankAccounts.isEmpty
            ? const EmptyState(icon: Icons.account_balance_outlined, title: 'Belum ada rekening')
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: bankAccounts.length,
                itemBuilder: (context, i) => AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bankAccounts[i].bankName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(bankAccounts[i].accountNumber, style: const TextStyle(fontSize: 16, letterSpacing: 1)),
                            Text(bankAccounts[i].accountHolder, style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => _remove(i),
                        icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
                      ),
                    ],
                  ),
                ),
              ),
        ),
      ],
    );
  }

  void _add(BuildContext context, WidgetRef ref) {
    final bankCtrl = TextEditingController();
    final numCtrl = TextEditingController();
    final holderCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Rekening'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: bankCtrl, decoration: const InputDecoration(labelText: 'Nama Bank')),
            const SizedBox(height: 12),
            TextField(controller: numCtrl, decoration: const InputDecoration(labelText: 'Nomor Rekening')),
            const SizedBox(height: 12),
            TextField(controller: holderCtrl, decoration: const InputDecoration(labelText: 'Nama Pemilik')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final updated = ref.read(settingsProvider).copyWith(
                bankAccounts: [...ref.read(settingsProvider).bankAccounts, BankAccount(
                  bankName: bankCtrl.text,
                  accountNumber: numCtrl.text,
                  accountHolder: holderCtrl.text,
                )],
              );
              ref.read(settingsProvider.notifier).updateSettings(updated);
              Navigator.pop(context);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  void _remove(int i) {
    final list = List<BankAccount>.from(ref.read(settingsProvider).bankAccounts);
    list.removeAt(i);
    ref.read(settingsProvider.notifier).updateSettings(ref.read(settingsProvider).copyWith(bankAccounts: list));
  }
}

class _SecuritySheet extends ConsumerWidget {
  const _SecuritySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final hasPin = settings.securityPin != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 5, width: 40, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(5))),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Keamanan & PIN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(hasPin ? Icons.lock_rounded : Icons.lock_open_rounded, size: 64, color: hasPin ? AppTheme.success : AppTheme.warning),
              const SizedBox(height: 16),
              Text(hasPin ? 'PIN Keamanan Aktif' : 'PIN Belum Diatur', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('PIN digunakan untuk melindungi data finansial dan menghapus transaksi.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => _setupPin(context, ref),
                child: Text(hasPin ? 'Ubah PIN' : 'Setel PIN Sekarang'),
              ),
              if (hasPin)
                TextButton(
                  onPressed: () => ref.read(settingsProvider.notifier).updateSettings(settings.copyWith(securityPin: null)),
                  child: const Text('Nonaktifkan PIN', style: TextStyle(color: AppTheme.danger)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _setupPin(BuildContext context, WidgetRef ref) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setel PIN (4-6 Digit)'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 10),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (pinCtrl.text.length < 4) return;
              ref.read(settingsProvider.notifier).updateSettings(ref.read(settingsProvider).copyWith(securityPin: pinCtrl.text));
              Navigator.pop(context);
              showSuccess(context, 'PIN Berhasil Disimpan');
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}

class _DisplaySettingsSheet extends ConsumerWidget {
  const _DisplaySettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        SwitchListTile.adaptive(
          title: const Text('Layar Penuh (Full Screen)'),
          secondary: const Icon(Icons.fullscreen_rounded),
          value: appSettings.isFullScreen,
          onChanged: (v) => ref.read(appSettingsProvider.notifier).setFullScreen(v),
        ),
        SwitchListTile.adaptive(
          title: const Text('Tampilan Pelanggan'),
          secondary: const Icon(Icons.monitor_rounded),
          value: appSettings.isCustomerDisplayEnabled,
          onChanged: (v) => ref.read(appSettingsProvider.notifier).setCustomerDisplay(v),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
