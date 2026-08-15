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
import '../../../../shared/widgets/security_gate.dart';
import '../widgets/printing_settings_widget.dart';

enum SettingsSection { store, payment, printing, security, display, backup }

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  SettingsSection _currentSection = SettingsSection.store;

  late TextEditingController _businessNameCtrl;
  late TextEditingController _ownerNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _receiptWidthCtrl;
  late TextEditingController _receiptMarginCtrl;

  bool _useFastPrint = false;
  String _printerTransport = 'pdf';
  String? _invoicePrinterUrl;

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
    _receiptWidthCtrl =
        TextEditingController(text: settings.receiptWidth.toString());
    _receiptMarginCtrl =
        TextEditingController(text: settings.receiptMargin.toString());
    _useFastPrint = settings.useFastPrint;
    _printerTransport = settings.printerTransport;
    _invoicePrinterUrl = settings.invoicePrinterUrl;
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
    _receiptWidthCtrl.dispose();
    _receiptMarginCtrl.dispose();
    super.dispose();
  }

  void _addBankAccount() {
    setState(() {
      _bankAccounts.add(
          const BankAccount(bankName: '', accountNumber: '', accountHolder: ''));
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
            receiptWidth: double.tryParse(_receiptWidthCtrl.text) ?? 80.0,
            receiptMargin: double.tryParse(_receiptMarginCtrl.text) ?? 4.0,
            useFastPrint: _useFastPrint,
            printerTransport: _printerTransport,
            invoicePrinterUrl: _invoicePrinterUrl,
            bankAccounts: _bankAccounts,
          );

      ref.read(settingsProvider.notifier).updateSettings(settings);
      showSuccess(context, 'Pengaturan berhasil disimpan');
    }
  }

  Future<void> _handleFullBackup(WidgetRef ref) async {
    debugPrint('DEBUG: _handleFullBackup invoked');

    // 1. Fetch data from cache first
    final products = ref.read(productsProvider).asData?.value ?? [];
    final restocks = ref.read(restockHistoryProvider).asData?.value ?? [];
    final billPayments = ref.read(billPaymentsProvider).asData?.value ?? [];
    final customers = ref.read(customersProvider).asData?.value ?? [];
    final customerDebts = ref.read(debtsProvider(null)).asData?.value ?? [];
    final customerPayments =
        ref.read(debtPaymentsProvider((customerId: null, debtId: null))).asData?.value ?? [];
    final transactions = ref.read(transactionsProvider).asData?.value ?? [];
    final settings = ref.read(settingsProvider);

    debugPrint(
        'DEBUG: Data counts - Products: ${products.length}, Transactions: ${transactions.length}');

    // 2. Immediate Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Membuka Folder Picker...'),
          duration: Duration(seconds: 1)),
    );

    try {
      await BackupHelper.performFullBackup(
        context: context,
        products: products,
        restocks: restocks,
        billPayments: billPayments,
        customers: customers,
        customerDebts: customerDebts,
        customerPayments: customerPayments,
        transactions: transactions,
        settings: settings,
      );

      if (mounted) showSuccess(context, 'Backup Berhasil Disimpan!');
    } catch (e, stack) {
      debugPrint('DEBUG: Backup FATAL ERROR: $e');
      debugPrint('DEBUG: StackTrace: $stack');
      if (mounted) showError(context, 'Gagal Backup: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sync UI with provider changes
    ref.listen(settingsProvider, (prev, next) {
      if (_businessNameCtrl.text.isEmpty && next.businessName.isNotEmpty) {
        _businessNameCtrl.text = next.businessName;
        _ownerNameCtrl.text = next.ownerName;
        _phoneCtrl.text = next.phone;
        _emailCtrl.text = next.email;
        _addressCtrl.text = next.address;
        _descriptionCtrl.text = next.description;
        _receiptWidthCtrl.text = next.receiptWidth.toString();
        _receiptMarginCtrl.text = next.receiptMargin.toString();
        _invoicePrinterUrl = next.invoicePrinterUrl;
        setState(() {
          _bankAccounts = List.from(next.bankAccounts);
          _useFastPrint = next.useFastPrint;
          _printerTransport = next.printerTransport;
        });
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          PageHeader(
            title: 'Pengaturan Akun & Toko',
            icon: Icons.settings_rounded,
            actions: [
              OutlinedButton.icon(
                onPressed: () async {
                  if (await showLogoutDialog(context)) {
                    if (mounted) ref.read(authRepositoryProvider).logout();
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Keluar (Logout)'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.danger,
                    side: const BorderSide(color: AppTheme.danger)),
              ),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Simpan Perubahan'),
              ),
            ],
          ),
          Expanded(
            child: Row(
              children: [
                _buildSidebar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: _buildSectionContent(),
                        ),
                      ),
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

  Widget _buildSidebar() {
    return Container(
      width: 240,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        children: [
          _SidebarItem(
            icon: Icons.store_rounded,
            label: 'Informasi Toko',
            isSelected: _currentSection == SettingsSection.store,
            onTap: () => setState(() => _currentSection = SettingsSection.store),
          ),
          _SidebarItem(
            icon: Icons.payments_rounded,
            label: 'Metode Pembayaran',
            isSelected: _currentSection == SettingsSection.payment,
            onTap: () => setState(() => _currentSection = SettingsSection.payment),
          ),
          _SidebarItem(
            icon: Icons.print_rounded,
            label: 'Format Struk',
            isSelected: _currentSection == SettingsSection.printing,
            onTap: () => setState(() => _currentSection = SettingsSection.printing),
          ),
          _SidebarItem(
            icon: Icons.security_rounded,
            label: 'Keamanan (PIN)',
            isSelected: _currentSection == SettingsSection.security,
            onTap: () => setState(() => _currentSection = SettingsSection.security),
          ),
          _SidebarItem(
            icon: Icons.display_settings_rounded,
            label: 'Tampilan Aplikasi',
            isSelected: _currentSection == SettingsSection.display,
            onTap: () => setState(() => _currentSection = SettingsSection.display),
          ),
          _SidebarItem(
            icon: Icons.backup_rounded,
            label: 'Data & Backup',
            isSelected: _currentSection == SettingsSection.backup,
            onTap: () => setState(() => _currentSection = SettingsSection.backup),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent() {
    switch (_currentSection) {
      case SettingsSection.store:
        return _buildStoreSection();
      case SettingsSection.payment:
        return _buildPaymentSection();
      case SettingsSection.printing:
        return _buildPrintingSection();
      case SettingsSection.security:
        return _buildSecuritySection();
      case SettingsSection.display:
        return _buildDisplaySection();
      case SettingsSection.backup:
        return _buildBackupSection();
    }
  }

  Widget _buildStoreSection() {
    final settings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Informasi Bisnis'),
        const SizedBox(height: 16),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _buildInput('Nama Bisnis / Toko', _businessNameCtrl,
                              Icons.business_rounded),
                          const SizedBox(height: 16),
                          _buildInput('Nama Pemilik', _ownerNameCtrl,
                              Icons.person_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    _buildLogoPicker(settings),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildInput(
                            'Nomor Telepon', _phoneCtrl, Icons.phone_rounded)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildInput(
                            'Email Bisnis', _emailCtrl, Icons.email_rounded)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInput('Alamat Lengkap', _addressCtrl,
                    Icons.location_on_rounded,
                    maxLines: 2),
                const SizedBox(height: 16),
                _buildInput('Keterangan / Slogan', _descriptionCtrl,
                    Icons.description_rounded),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionTitle(title: 'Metode Pembayaran (QRIS)'),
        const SizedBox(height: 16),
        AppCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gambar QRIS Toko',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      SizedBox(height: 4),
                      Text(
                          'Upload gambar QRIS statis Anda (GPN/Dana/OVO/dll) untuk memudahkan pelanggan membayar via transfer QR.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                _buildQrisPicker(settings),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoPicker(StoreSettings settings) {
    return Column(
      children: [
        const Text('Logo Toko',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickLogo,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: settings.logoUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.network(settings.logoUrl!, fit: BoxFit.cover),
                  )
                : const Icon(Icons.add_a_photo_rounded,
                    color: AppTheme.textMuted),
          ),
        ),
        if (settings.logoUrl != null)
          TextButton(
            onPressed: () => ref
                .read(settingsProvider.notifier)
                .updateSettings(settings.copyWith(logoUrl: null)),
            child: const Text('HAPUS',
                style: TextStyle(color: AppTheme.danger, fontSize: 10)),
          ),
      ],
    );
  }

  Widget _buildQrisPicker(StoreSettings settings) {
    return FutureBuilder<String?>(
      future: ImageHelper.resolveLocalPath(settings.qrisImagePath),
      builder: (context, snapshot) {
        final localPath = snapshot.data;

        return Column(
          children: [
            InkWell(
              onTap: _pickQris,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: localPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(File(localPath), fit: BoxFit.contain),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded,
                              color: AppTheme.textMuted, size: 32),
                          SizedBox(height: 4),
                          Text('Upload QRIS',
                              style: TextStyle(
                                  fontSize: 10, color: AppTheme.textMuted)),
                        ],
                      ),
              ),
            ),
            if (localPath != null)
              TextButton(
                onPressed: () => ref
                    .read(settingsProvider.notifier)
                    .updateSettings(settings.copyWith(qrisImagePath: null)),
                child: const Text('HAPUS QRIS',
                    style: TextStyle(color: AppTheme.danger, fontSize: 10)),
              ),
          ],
        );
      },
    );
  }

  Future<void> _pickLogo() async {
    final bytes = await ImageHelper.pickAndCropImage(context);
    if (bytes == null) return;

    final processed = await ImageHelper.processImage(bytes);
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    // Upload to Firebase Storage
    final url = await ref
        .read(productsActionProvider)
        .uploadImage('store_logo_$uid', processed);
    if (url != null) {
      final current = ref.read(settingsProvider);
      ref
          .read(settingsProvider.notifier)
          .updateSettings(current.copyWith(logoUrl: url));
    }
  }

  Future<void> _pickQris() async {
    final bytes = await ImageHelper.pickAndCropImage(context);
    if (bytes == null) return;

    final processed = await ImageHelper.processImage(bytes);
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final localPath = await ImageHelper.saveLocally(
        uid, 'qris_static_$uid.jpg', processed,
        subFolder: 'settings');
    if (localPath != null) {
      final current = ref.read(settingsProvider);
      ref
          .read(settingsProvider.notifier)
          .updateSettings(current.copyWith(qrisImagePath: localPath));
    }
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _SectionTitle(title: 'Metode Pembayaran (Transfer)'),
            const Spacer(),
            TextButton.icon(
              onPressed: _addBankAccount,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('TAMBAH REKENING'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_bankAccounts.isEmpty)
          const Center(
              child: Text('Belum ada rekening',
                  style: TextStyle(color: AppTheme.textSecondary)))
        else
          for (int i = 0; i < _bankAccounts.length; i++) _buildBankCard(i),
      ],
    );
  }

  Widget _buildPrintingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Pengaturan Printer & Struk'),
        const SizedBox(height: 16),
        PrintingSettingsWidget(
          widthCtrl: _receiptWidthCtrl,
          marginCtrl: _receiptMarginCtrl,
          useFastPrint: _useFastPrint,
          printerTransport: _printerTransport,
          invoicePrinterUrl: _invoicePrinterUrl,
          onFastPrintChanged: (v) => setState(() => _useFastPrint = v),
          onTransportChanged: (v) => setState(() => _printerTransport = v),
          onInvoicePrinterChanged: (v) =>
              setState(() => _invoicePrinterUrl = v),
        ),
      ],
    );
  }

  Widget _buildSecuritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Keamanan Data'),
        const SizedBox(height: 16),
        _buildPinSetting(ref),
      ],
    );
  }

  Widget _buildDisplaySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Pengaturan Tampilan & Tema'),
        const SizedBox(height: 16),
        _buildAppSettings(ref),
      ],
    );
  }

  Widget _buildBackupSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Data & Backup'),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.download_for_offline_rounded,
                    color: AppTheme.accent),
                title: const Text('Backup Keseluruhan (Excel)',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Download 3 file Excel: Master Produk, Piutang Pelanggan, dan Analitik Penjualan'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _handleFullBackup(ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPageLockToggle({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_person_rounded, size: 20, color: AppTheme.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }

  void _updatePageLock(StoreSettings Function() updateFn) {
    requirePin(context, ref, () {
      final updated = updateFn();
      ref.read(settingsProvider.notifier).updateSettings(updated);
      showSuccess(context, 'Pengaturan proteksi diperbarui');
    });
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 20),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildPinSetting(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final hasPin =
        settings.securityPin != null && settings.securityPin!.length == 4;

    return AppCard(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
                hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: hasPin ? AppTheme.success : AppTheme.warning),
            title: Text(hasPin ? 'PIN Keamanan Aktif' : 'PIN Keamanan Belum Diatur'),
            subtitle: Text(hasPin
                ? 'Gunakan PIN untuk membatasi akses fitur sensitif'
                : 'Atur PIN agar data toko lebih aman'),
            trailing: ElevatedButton(
              onPressed: () => _showPinDialog(hasPin),
              child: Text(hasPin ? 'UBAH PIN' : 'BUAT PIN'),
            ),
          ),
          if (hasPin) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPageLockToggle(
                    label: 'Proteksi Halaman Analitik',
                    subtitle: 'Minta PIN saat membuka dashboard analitik',
                    value: settings.lockAnalyticsPage,
                    onChanged: (v) => _updatePageLock(
                        () => settings.copyWith(lockAnalyticsPage: v)),
                  ),
                  const SizedBox(height: 12),
                  _buildPageLockToggle(
                    label: 'Proteksi Halaman Produk',
                    subtitle: 'Minta PIN saat mengelola stok & harga produk',
                    value: settings.lockProductsPage,
                    onChanged: (v) => _updatePageLock(
                        () => settings.copyWith(lockProductsPage: v)),
                  ),
                  const SizedBox(height: 12),
                  _buildPageLockToggle(
                    label: 'Proteksi Halaman Inventory',
                    subtitle: 'Minta PIN saat membuka halaman inventory',
                    value: settings.lockInventoryPage,
                    onChanged: (v) => _updatePageLock(
                        () => settings.copyWith(lockInventoryPage: v)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showPinDialog(bool isUpdate) {
    final pinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isUpdate ? 'Ubah PIN Keamanan' : 'Buat PIN Keamanan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Masukkan 4 digit angka PIN Anda',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              TextFormField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24, letterSpacing: 16, fontWeight: FontWeight.bold),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(counterText: ''),
                validator: (v) =>
                    (v?.length ?? 0) < 4 ? 'PIN harus 4 digit' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final settings =
                    ref.read(settingsProvider).copyWith(securityPin: pinCtrl.text);
                ref.read(settingsProvider.notifier).updateSettings(settings);
                Navigator.pop(context);
                showSuccess(context, 'PIN berhasil disimpan');
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettings(WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return AppCard(
      child: Column(
        children: [
          SwitchListTile.adaptive(
            value: appSettings.isFullScreen,
            onChanged: (v) => notifier.setFullScreen(v),
            title: const Text('Mode Layar Penuh (Kiosk)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text(
                'Menghilangkan toolbar Windows agar tampilan lebih fokus',
                style: TextStyle(fontSize: 12)),
            activeTrackColor: AppTheme.accent,
          ),
          const Divider(height: 1),
          SwitchListTile.adaptive(
            value: appSettings.isCustomerDisplayEnabled,
            onChanged: (v) => notifier.setCustomerDisplay(v),
            title: const Text('Layar Pelanggan (Customer Display)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: const Text('Tampilkan rincian belanja di monitor kedua',
                style: TextStyle(fontSize: 12)),
            activeTrackColor: AppTheme.accent,
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Skala Tampilan UI',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const Text(
                          'Sesuaikan ukuran teks & tombol (Rekomendasi: 100%)',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: Slider(
                    value: appSettings.displayScale,
                    min: 0.7,
                    max: 1.2,
                    divisions: 10,
                    label: '${(appSettings.displayScale * 100).toInt()}%',
                    activeColor: AppTheme.accent,
                    onChanged: (v) => notifier.setDisplayScale(v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
                  setState(() => _bankAccounts[i] = BankAccount(
                      bankName: v,
                      accountNumber: account.accountNumber,
                      accountHolder: account.accountHolder));
                }),
              ),
              IconButton(
                  onPressed: () => _removeBankAccount(i),
                  icon: const Icon(Icons.delete_outline, color: AppTheme.danger)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSmallInput('Nomor Rekening', account.accountNumber,
                    (v) {
                  setState(() => _bankAccounts[i] = BankAccount(
                      bankName: account.bankName,
                      accountNumber: v,
                      accountHolder: account.accountHolder));
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSmallInput('Pemilik', account.accountHolder, (v) {
                  setState(() => _bankAccounts[i] = BankAccount(
                      bankName: account.bankName,
                      accountNumber: account.accountNumber,
                      accountHolder: v));
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallInput(
      String label, String initial, ValueChanged<String> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initial,
          onChanged: onChanged,
          decoration: const InputDecoration(
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
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
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: AppTheme.accent,
          letterSpacing: 1),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppTheme.accent.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon,
            color: isSelected ? AppTheme.accent : AppTheme.textSecondary,
            size: 20),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.accent : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
