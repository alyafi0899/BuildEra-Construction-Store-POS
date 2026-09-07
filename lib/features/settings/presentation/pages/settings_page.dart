import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../products/providers/product_provider.dart';
import '../../models/store_settings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../widgets/printing_settings_widget.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';
import '../../../subscription/presentation/pages/payment_gateway_page.dart';
import '../../../subscription/providers/subscription_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _activeTab = 0;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _receiptWidthCtrl = TextEditingController();
  final _receiptMarginCtrl = TextEditingController();

  // State for non-text settings
  List<BankAccount> _bankAccounts = [];
  bool _useFastPrint = false;
  String _printerTransport = 'pdf';
  String _invoiceDesign = 'classic';
  String _printMethod = 'pdf';
  String? _invoicePrinterUrl;

  bool _initialized = false;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _descCtrl.dispose();
    _receiptWidthCtrl.dispose();
    _receiptMarginCtrl.dispose();
    super.dispose();
  }

  void _initFields(StoreSettings settings) {
    if (_initialized) return;
    _businessNameCtrl.text = settings.businessName;
    _ownerNameCtrl.text = settings.ownerName;
    _phoneCtrl.text = settings.phone;
    _emailCtrl.text = settings.email;
    _addressCtrl.text = settings.address;
    _descCtrl.text = settings.description;
    _bankAccounts = List.from(settings.bankAccounts);
    _receiptWidthCtrl.text = settings.receiptWidth.toString();
    _receiptMarginCtrl.text = settings.receiptMargin.toString();
    _useFastPrint = settings.useFastPrint;
    _printerTransport = settings.printerTransport;
    _invoiceDesign = settings.invoiceDesign;
    _printMethod = settings.printMethod;
    _invoicePrinterUrl = settings.invoicePrinterUrl;
    _initialized = true;
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    final current = ref.read(settingsProvider);
    final updated = current.copyWith(
      businessName: _businessNameCtrl.text.trim(),
      ownerName: _ownerNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      bankAccounts: _bankAccounts,
      receiptWidth: double.tryParse(_receiptWidthCtrl.text) ?? 80.0,
      receiptMargin: double.tryParse(_receiptMarginCtrl.text) ?? 4.0,
      useFastPrint: _useFastPrint,
      printerTransport: _printerTransport,
      invoiceDesign: _invoiceDesign,
      printMethod: _printMethod,
      invoicePrinterUrl: _invoicePrinterUrl,
    );

    try {
      await ref.read(settingsProvider.notifier).updateSettings(updated);
      if (mounted) showSuccess(context, 'Pengaturan berhasil disimpan');
    } catch (e) {
      if (mounted) showError(context, 'Gagal menyimpan pengaturan: $e');
    }
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi? Sesi Anda akan berakhir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              ref.read(authRepositoryProvider).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger, foregroundColor: Colors.white),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    _initFields(settings);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(
        children: [
          // Sidebar Pengaturan
          Container(
            width: 280,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(right: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('PENGATURAN',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
                _SidebarItem(
                  icon: Icons.store_rounded,
                  label: 'Informasi Toko',
                  isSelected: _activeTab == 0,
                  onTap: () => setState(() => _activeTab = 0),
                ),
                _SidebarItem(
                  icon: Icons.account_balance_rounded,
                  label: 'Pembayaran & Bank',
                  isSelected: _activeTab == 1,
                  onTap: () => setState(() => _activeTab = 1),
                ),
                _SidebarItem(
                  icon: Icons.print_rounded,
                  label: 'Printer & Struk',
                  isSelected: _activeTab == 2,
                  onTap: () => setState(() => _activeTab = 2),
                ),
                _SidebarItem(
                  icon: Icons.security_rounded,
                  label: 'Keamanan Data',
                  isSelected: _activeTab == 3,
                  onTap: () => setState(() => _activeTab = 3),
                ),
                _SidebarItem(
                  icon: Icons.display_settings_rounded,
                  label: 'Tampilan Aplikasi',
                  isSelected: _activeTab == 4,
                  onTap: () => setState(() => _activeTab = 4),
                ),
                _SidebarItem(
                  icon: Icons.stars_rounded,
                  label: 'Paket Langganan',
                  isSelected: _activeTab == 5,
                  onTap: () => setState(() => _activeTab = 5),
                  trailing: ref.watch(isPremiumProvider)
                      ? const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16)
                      : null,
                ),
                const SizedBox(height: 12),
                _SidebarItem(
                  icon: Icons.logout_rounded,
                  label: 'Keluar / Logout',
                  isSelected: false,
                  iconColor: AppTheme.danger,
                  textColor: AppTheme.danger,
                  onTap: () => _handleLogout(context),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: ElevatedButton.icon(
                    onPressed: _saveSettings,
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('SIMPAN PERUBAHAN'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Konten Utama
          Expanded(
            child: _activeTab == 5 
                ? Consumer(
                    builder: (context, ref, child) {
                      final gateway = ref.watch(gatewayStateProvider);
                      if (gateway.method != null && gateway.plan != null) {
                        return PaymentGatewayPage(
                          method: gateway.method!,
                          plan: gateway.plan!,
                          onBack: () => ref.read(gatewayStateProvider.notifier).reset(),
                        );
                      }
                      return SubscriptionPage(
                        onBackToSummary: () {}, // Simply mark as being in settings
                      );
                    },
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(40),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_activeTab == 0) _buildStoreSection(),
                          if (_activeTab == 1) _buildPaymentSection(),
                          if (_activeTab == 2) _buildPrintingSection(),
                          if (_activeTab == 3) _buildSecuritySection(),
                          if (_activeTab == 4) _buildDisplaySection(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Identitas Bisnis'),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLogoPicker(),
            const SizedBox(width: 40),
            Expanded(
              child: Column(
                children: [
                  _LocalTextField(
                    controller: _businessNameCtrl,
                    label: 'Nama Toko / Perusahaan',
                    prefixIcon: const Icon(Icons.business_rounded),
                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 20),
                  _LocalTextField(
                    controller: _ownerNameCtrl,
                    label: 'Nama Pemilik',
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _LocalTextField(
                controller: _phoneCtrl,
                label: 'Nomor Telepon / WhatsApp',
                prefixIcon: const Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _LocalTextField(
                controller: _emailCtrl,
                label: 'Email Bisnis',
                prefixIcon: const Icon(Icons.email_rounded),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _LocalTextField(
          controller: _addressCtrl,
          label: 'Alamat Lengkap',
          prefixIcon: const Icon(Icons.location_on_rounded),
          maxLines: 3,
        ),
        const SizedBox(height: 20),
        _LocalTextField(
          controller: _descCtrl,
          label: 'Deskripsi / Slogan Toko',
          prefixIcon: const Icon(Icons.notes_rounded),
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildLogoPicker() {
    final settings = ref.watch(settingsProvider);
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            image: settings.logoUrl != null
                ? DecorationImage(
                    image: NetworkImage(settings.logoUrl!), fit: BoxFit.cover)
                : null,
          ),
          child: settings.logoUrl == null
              ? const Icon(Icons.add_a_photo_rounded,
                  size: 40, color: AppTheme.textMuted)
              : null,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _pickLogo,
          child: const Text('GANTI LOGO', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Future<void> _pickLogo() async {
    final bytes = await ImageHelper.pickAndCropImage(context);
    if (bytes == null) return;
    final processed = await ImageHelper.processImage(bytes);
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final url = await ref
        .read(productsActionProvider)
        .uploadImage('store_logo_$uid', processed);
    if (url != null) {
      final current = ref.read(settingsProvider);
      await ref
          .read(settingsProvider.notifier)
          .updateSettings(current.copyWith(logoUrl: url));
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

  void _addBankAccount() {
    setState(() {
      _bankAccounts.add(const BankAccount(
          bankName: '', accountNumber: '', accountHolder: ''));
    });
  }

  Widget _buildBankCard(int index) {
    final account = _bankAccounts[index];
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(4), // Inner padding since AppCard already has padding
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: _buildSmallInput('Nama Bank', account.bankName, (v) {
                _bankAccounts[index] = BankAccount(
                    bankName: v,
                    accountNumber: account.accountNumber,
                    accountHolder: account.accountHolder);
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _buildSmallInput('No. Rekening', account.accountNumber, (v) {
                _bankAccounts[index] = BankAccount(
                    bankName: account.bankName,
                    accountNumber: v,
                    accountHolder: account.accountHolder);
              }),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: _buildSmallInput('Atas Nama', account.accountHolder, (v) {
                _bankAccounts[index] = BankAccount(
                    bankName: account.bankName,
                    accountNumber: account.accountNumber,
                    accountHolder: v);
              }),
            ),
            IconButton(
              onPressed: () => setState(() => _bankAccounts.removeAt(index)),
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.danger),
            ),
          ],
        ),
      ),
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
          invoiceDesign: _invoiceDesign,
          printMethod: _printMethod,
          invoicePrinterUrl: _invoicePrinterUrl,
          onFastPrintChanged: (v) => setState(() => _useFastPrint = v),
          onTransportChanged: (v) => setState(() => _printerTransport = v),
          onDesignChanged: (v) => setState(() => _invoiceDesign = v),
          onMethodChanged: (v) => setState(() => _printMethod = v),
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
        const SizedBox(height: 24),
        _buildPinSetting(ref),
      ],
    );
  }

  Widget _buildPinSetting(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final hasPin =
        settings.securityPin != null && settings.securityPin!.length >= 4;

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
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPin)
                  TextButton(
                    onPressed: _showForgotPinDialog,
                    child: const Text('LUPA PIN?', style: TextStyle(color: AppTheme.danger, fontSize: 12)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _showPinDialog(hasPin),
                  child: Text(hasPin ? 'UBAH PIN' : 'BUAT PIN'),
                ),
              ],
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

  void _updatePageLock(StoreSettings Function() updater) {
    final updated = updater();
    ref.read(settingsProvider.notifier).updateSettings(updated);
  }

  Widget _buildPageLockToggle({required String label, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: AppTheme.accent),
      ],
    );
  }

  void _showPinDialog(bool isUpdate) {
    final oldPinCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();
    final confirmPinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int step = isUpdate ? 0 : 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isUpdate ? 'Ubah PIN Keamanan' : 'Buat PIN Keamanan'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step == 0) ...[
                  const Text('Masukkan PIN Lama Anda', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  _buildPinField(oldPinCtrl),
                ] else if (step == 1) ...[
                  const Text('Masukkan PIN Baru (4-6 Digit)', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  _buildPinField(newPinCtrl),
                ] else ...[
                  const Text('Konfirmasi PIN Baru Anda', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  _buildPinField(confirmPinCtrl),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                
                if (step == 0) {
                  final currentPin = ref.read(settingsProvider).securityPin;
                  if (oldPinCtrl.text != currentPin) {
                    showError(context, 'PIN lama salah!');
                    return;
                  }
                  setDialogState(() => step = 1);
                } else if (step == 1) {
                  setDialogState(() => step = 2);
                } else {
                  if (newPinCtrl.text != confirmPinCtrl.text) {
                    showError(context, 'Konfirmasi PIN tidak cocok!');
                    return;
                  }
                  final settings = ref.read(settingsProvider).copyWith(securityPin: newPinCtrl.text);
                  ref.read(settingsProvider.notifier).updateSettings(settings);
                  Navigator.pop(context);
                  showSuccess(context, 'PIN berhasil diperbarui');
                }
              },
              child: Text(step == 2 ? 'SIMPAN' : 'LANJUT'),
            ),
          ],
        ),
      ),
    );
  }

  void _showForgotPinDialog() {
    final passCtrl = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reset PIN via Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Untuk mereset PIN, silakan masukkan password akun Anda untuk verifikasi identitas.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: passCtrl,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Password Akun',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('BATAL')),
            ElevatedButton(
              onPressed: () async {
                final email = ref.read(authStateProvider).value?.email;
                if (email == null) return;
                
                try {
                  _showLocalLoadingDialog('Memverifikasi...');
                  await ref.read(authRepositoryProvider).verifyCredentials(email, passCtrl.text);
                  
                  if (!mounted) return;
                  Navigator.pop(context); // Close loading
                  Navigator.pop(context); // Close password dialog
                  _showPinDialog(false); // Open "Create PIN" flow
                  showSuccess(context, 'Verifikasi sukses! Silakan buat PIN baru.');
                } catch (e) {
                  if (!mounted) return;
                  Navigator.pop(context); // Close loading
                  showError(context, e.toString());
                }
              },
              child: const Text('VERIFIKASI'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocalLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text(message),
          ],
        ),
      ),
    );
  }

  Widget _buildPinField(TextEditingController ctrl) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      maxLength: 6,
      obscureText: true,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(counterText: '', contentPadding: EdgeInsets.zero),
      validator: (v) => (v?.length ?? 0) < 4 ? 'Minimal 4 digit' : null,
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Skala Tampilan UI',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Sesuaikan ukuran elemen antarmuka',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: Row(
                    children: [
                      const Text('80%', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      Expanded(
                        child: Slider(
                          value: appSettings.displayScale,
                          min: 0.8,
                          max: 1.2,
                          divisions: 8, // 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15, 1.2
                          label: '${(appSettings.displayScale * 100).toInt()}%',
                          activeColor: AppTheme.accent,
                          onChanged: (v) => notifier.setDisplayScale(double.parse(v.toStringAsFixed(2))),
                        ),
                      ),
                      const Text('120%', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(appSettings.displayScale * 100).toInt()}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accent),
                ),
              ],
            ),
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

class _LocalTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final int maxLines;

  const _LocalTextField({
    required this.controller,
    required this.label,
    this.prefixIcon,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon,
      ),
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
  final Widget? trailing;
  final Color? iconColor;
  final Color? textColor;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.trailing,
    this.iconColor,
    this.textColor,
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
            color: isSelected ? AppTheme.accent : (iconColor ?? AppTheme.textSecondary),
            size: 20),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? AppTheme.accent : (textColor ?? AppTheme.textPrimary),
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
