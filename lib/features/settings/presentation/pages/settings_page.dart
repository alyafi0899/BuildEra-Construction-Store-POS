import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/store_settings.dart';
import '../../providers/settings_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../widgets/printing_settings_widget.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';
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
  final _adminBypassCtrl = TextEditingController();

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
    _adminBypassCtrl.dispose();
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
        content: const Text(
            'Apakah Anda yakin ingin keluar dari aplikasi? Sesi Anda akan berakhir.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('BATAL')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              ref.read(authRepositoryProvider).logout();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white),
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

    Widget buildCompactTopMenu() {
      final items = [
        (0, Icons.store_rounded, 'Toko'),
        (1, Icons.account_balance_rounded, 'Pembayaran'),
        (2, Icons.print_rounded, 'Printer'),
        (3, Icons.security_rounded, 'Keamanan'),
        (4, Icons.display_settings_rounded, 'Tampilan'),
        (5, Icons.stars_rounded, 'Langganan'),
      ];

      return Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('PENGATURAN',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                  onPressed: () => _handleLogout(context),
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
                  tooltip: 'Keluar',
                ),
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Simpan'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: items.map((item) {
                  final isSelected = _activeTab == item.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: isSelected,
                      showCheckmark: false,
                      avatar: Icon(item.$2,
                          size: 16,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary),
                      label: Text(item.$3),
                      selectedColor: AppTheme.accent,
                      onSelected: (_) => setState(() => _activeTab = item.$1),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 800;

          final mainContent = _activeTab == 5
              ? const SubscriptionPage()
              : SingleChildScrollView(
                  padding: EdgeInsets.all(isCompact ? 16 : 40),
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
                );

          if (isCompact) {
            return Column(
              children: [
                buildCompactTopMenu(),
                Expanded(child: mainContent),
              ],
            );
          }

          return Row(
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
                          ? const Icon(Icons.check_circle_rounded,
                              color: AppTheme.success, size: 16)
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
              Expanded(child: mainContent),
            ],
          );
        },
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
        FutureBuilder<String?>(
          future: ImageHelper.resolveLocalPath(settings.logoUrl),
          builder: (context, snapshot) {
            final resolved = snapshot.data;
            final hasLogo = resolved != null && resolved.isNotEmpty;

            return Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasLogo
                  ? Image.file(
                      File(resolved),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.broken_image_rounded,
                          size: 40,
                          color: AppTheme.textMuted),
                    )
                  : const Icon(Icons.add_a_photo_rounded,
                      size: 40, color: AppTheme.textMuted),
            );
          },
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

    final processed =
        await ImageHelper.processImage(bytes, maxDimension: 1200, quality: 90);
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final localPath = await ImageHelper.saveLocally(
        uid, 'store_logo_$uid.jpg', processed,
        subFolder: 'brand_assets');
    if (localPath == null) {
      if (mounted) showError(context, 'Gagal menyimpan logo lokal.');
      return;
    }

    final current = ref.read(settingsProvider);
    try {
      await ref
          .read(settingsProvider.notifier)
          .updateSettings(current.copyWith(logoUrl: localPath));
      if (mounted) showSuccess(context, 'Logo berhasil disimpan secara lokal.');
    } catch (e) {
      if (mounted) {
        showSuccess(context,
            'Logo tersimpan di perangkat. Sinkronisasi pengaturan cloud gagal.');
      }
    }
  }

  Future<void> _pickQrisImage() async {
    final bytes = await ImageHelper.pickAndCropImage(context);
    if (bytes == null) return;

    final processed =
        await ImageHelper.processImage(bytes, maxDimension: 1400, quality: 92);
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    final localPath = await ImageHelper.saveLocally(
        uid, 'qris_image_$uid.jpg', processed,
        subFolder: 'brand_assets');
    if (localPath == null) {
      if (mounted) showError(context, 'Gagal menyimpan foto QRIS lokal.');
      return;
    }

    final current = ref.read(settingsProvider);
    try {
      await ref
          .read(settingsProvider.notifier)
          .updateSettings(current.copyWith(qrisImagePath: localPath));
      if (mounted) showSuccess(context, 'Foto QRIS berhasil disimpan.');
    } catch (e) {
      if (mounted) {
        showSuccess(context,
            'Foto QRIS tersimpan di perangkat. Sinkronisasi pengaturan cloud gagal.');
      }
    }
  }

  bool _isAdminUser() {
    final email =
        (ref.read(authStateProvider).value?.email ?? '').toLowerCase();
    return email == 'admin@buildera.com' ||
        email.endsWith('@admin.buildera.com') ||
        email.endsWith('@buildera.com');
  }

  Future<void> _setAdminBypass({required bool enabled}) async {
    final rawValue = _adminBypassCtrl.text.trim();
    if (rawValue.isEmpty) {
      showError(context, 'Masukkan user ID atau email akun tujuan.');
      return;
    }

    try {
      final client = ref.read(supabaseClientProvider);
      final lookup = await client
          .from('users')
          .select('id')
          .or('id.eq.$rawValue,login_email.ilike.$rawValue')
          .maybeSingle();

      final targetUserId = lookup?['id']?.toString() ?? rawValue;
      await ref
          .read(subscriptionRepositoryProvider)
          .setBypassStatus(targetUserId, enabled);
      if (mounted) {
        showSuccess(
            context,
            enabled
                ? 'Bypass langganan diaktifkan untuk akun target.'
                : 'Bypass langganan dinonaktifkan untuk akun target.');
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal mengubah bypass langganan: $e');
    }
  }

  Widget _buildPaymentSection() {
    final settings = ref.watch(settingsProvider);
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
        const SizedBox(height: 30),
        const _SectionTitle(title: 'Foto QRIS Pembayaran'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.surfaceAlt,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gambar QRIS akan tampil pada metode pembayaran QRIS saat transaksi.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _pickQrisImage,
                    icon: const Icon(Icons.qr_code_rounded, size: 18),
                    label: const Text('UPLOAD QRIS'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FutureBuilder<String?>(
                future: ImageHelper.resolveLocalPath(settings.qrisImagePath),
                builder: (context, snapshot) {
                  final resolved = snapshot.data;
                  final hasImage = resolved != null && resolved.isNotEmpty;

                  return Center(
                    child: Container(
                      width: 230,
                      height: 290,
                      decoration: BoxDecoration(
                        color: AppTheme.bg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasImage
                          ? Image.file(
                              File(resolved),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image_rounded,
                                      size: 80, color: AppTheme.textSecondary),
                            )
                          : const Icon(Icons.qr_code_rounded,
                              size: 80, color: AppTheme.textSecondary),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.all(
            4), // Inner padding since AppCard already has padding
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
              child:
                  _buildSmallInput('No. Rekening', account.accountNumber, (v) {
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
        const _SectionTitle(title: 'Keamanan Data & Akun'),
        const SizedBox(height: 24),
        _buildPinSetting(ref),
        const SizedBox(height: 24),
        _buildPasswordSetting(),
        if (_isAdminUser()) ...[
          const SizedBox(height: 24),
          _buildAdminBypassSection(),
        ],
      ],
    );
  }

  Widget _buildAdminBypassSection() {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Admin: Bypass Langganan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Masukkan user ID atau email akun yang ingin diaktifkan bypass langganannya.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: _adminBypassCtrl,
              decoration: const InputDecoration(
                labelText: 'User ID / Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _setAdminBypass(enabled: true),
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('AKTIFKAN BYPASS'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.success),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _setAdminBypass(enabled: false),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('NONAKTIFKAN'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSetting() {
    final email = ref.watch(authStateProvider).value?.email ?? 'Email Akun';
    return AppCard(
      child: ListTile(
        leading: const Icon(Icons.key_rounded, color: AppTheme.accent),
        title: const Text('Password Akun'),
        subtitle: Text('Email login: $email'),
        trailing: ElevatedButton(
          onPressed: _showChangePasswordDialog,
          child: const Text('UBAH PASSWORD'),
        ),
      ),
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
            leading: Icon(hasPin ? Icons.lock_rounded : Icons.lock_open_rounded,
                color: hasPin ? AppTheme.success : AppTheme.warning),
            title: Text(
                hasPin ? 'PIN Keamanan Aktif' : 'PIN Keamanan Belum Diatur'),
            subtitle: Text(hasPin
                ? 'Gunakan PIN untuk membatasi akses fitur sensitif'
                : 'Atur PIN agar data toko lebih aman'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasPin)
                  TextButton(
                    onPressed: _showForgotPinDialog,
                    child: const Text('LUPA PIN?',
                        style: TextStyle(color: AppTheme.danger, fontSize: 12)),
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

  Future<void> _updatePageLock(StoreSettings Function() updater) async {
    final current = ref.read(settingsProvider);
    final expectedPin = current.securityPin;
    if (expectedPin == null || expectedPin.length < 4) {
      showError(
          context, 'Atur PIN keamanan sebelum mengubah proteksi halaman.');
      return;
    }

    final pinController = TextEditingController();
    final enteredPin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Verifikasi PIN Keamanan'),
        content: TextField(
          controller: pinController,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Masukkan PIN',
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, pinController.text),
            child: const Text('VERIFIKASI'),
          ),
        ],
      ),
    );
    pinController.dispose();

    if (!mounted || enteredPin == null) return;
    if (enteredPin != expectedPin) {
      showError(context, 'PIN keamanan salah. Pengaturan tidak diubah.');
      return;
    }

    try {
      await ref.read(settingsProvider.notifier).updateSettings(updater());
    } catch (e) {
      if (mounted) showError(context, 'Gagal menyimpan proteksi halaman: $e');
    }
  }

  Widget _buildPageLockToggle(
      {required String label,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13)),
              Text(subtitle,
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ),
        Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppTheme.accent),
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
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isUpdate ? 'Ubah PIN Keamanan' : 'Buat PIN Keamanan'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step == 0) ...[
                  const Text('Masukkan PIN Lama Anda',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  _buildPinField(oldPinCtrl),
                ] else if (step == 1) ...[
                  const Text('Masukkan PIN Baru (4-6 Digit)',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  _buildPinField(newPinCtrl),
                ] else ...[
                  const Text('Konfirmasi PIN Baru Anda',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  _buildPinField(confirmPinCtrl),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('BATAL')),
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
                  final settings = ref
                      .read(settingsProvider)
                      .copyWith(securityPin: newPinCtrl.text);
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
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                    icon:
                        Icon(obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('BATAL')),
            ElevatedButton(
              onPressed: () async {
                final email = ref.read(authStateProvider).value?.email;
                if (email == null) return;
                final navigator = Navigator.of(dialogContext);

                try {
                  _showLocalLoadingDialog('Memverifikasi...');
                  await ref
                      .read(authRepositoryProvider)
                      .verifyCredentials(email, passCtrl.text);

                  if (!mounted || !dialogContext.mounted) return;

                  navigator.pop(); // Close loading
                  navigator.pop(); // Close password dialog
                  _showPinDialog(false); // Open "Create PIN" flow
                  showSuccess(this.context,
                      'Verifikasi sukses! Silakan buat PIN baru.');
                } catch (e) {
                  if (!mounted || !dialogContext.mounted) return;
                  navigator.pop(); // Close loading
                  showError(this.context, e.toString());
                }
              },
              child: const Text('VERIFIKASI'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureOld = true;
    bool obscureNew = true;
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ubah Password Akun'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: oldPassCtrl,
                  obscureText: obscureOld,
                  decoration: InputDecoration(
                    labelText: 'Password Saat Ini',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscureOld ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setDialogState(() => obscureOld = !obscureOld),
                    ),
                  ),
                  validator: (v) => (v?.isEmpty ?? true)
                      ? 'Password saat ini wajib diisi'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Password Baru (min 8 karakter)',
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                          obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () =>
                          setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                  validator: (v) =>
                      (v?.length ?? 0) < 8 ? 'Minimal 8 karakter' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPassCtrl,
                  obscureText: obscureNew,
                  decoration: const InputDecoration(
                    labelText: 'Konfirmasi Password Baru',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                  ),
                  validator: (v) => v != newPassCtrl.text
                      ? 'Password baru tidak cocok'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      final email = ref.read(authStateProvider).value?.email;
                      if (email == null) return;

                      setDialogState(() => loading = true);
                      try {
                        // 1. Verify old password credentials
                        await ref
                            .read(authRepositoryProvider)
                            .verifyCredentials(email, oldPassCtrl.text);

                        // 2. Update to new password
                        await ref
                            .read(authRepositoryProvider)
                            .updatePassword(newPassCtrl.text);

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        showSuccess(
                            context, 'Password akun Anda berhasil diperbarui!');
                      } catch (e) {
                        if (!context.mounted) return;
                        setDialogState(() => loading = false);
                        showError(context, e.toString());
                      }
                    },
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('SIMPAN'),
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
      style: const TextStyle(
          fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
          counterText: '', contentPadding: EdgeInsets.zero),
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
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: Row(
                    children: [
                      const Text('80%',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textMuted)),
                      Expanded(
                        child: Slider(
                          value: appSettings.displayScale,
                          min: 0.8,
                          max: 1.2,
                          divisions:
                              8, // 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15, 1.2
                          label: '${(appSettings.displayScale * 100).toInt()}%',
                          activeColor: AppTheme.accent,
                          onChanged: (v) => notifier.setDisplayScale(
                              double.parse(v.toStringAsFixed(2))),
                        ),
                      ),
                      const Text('120%',
                          style: TextStyle(
                              fontSize: 10, color: AppTheme.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(appSettings.displayScale * 100).toInt()}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: AppTheme.accent),
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
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
            color: isSelected
                ? AppTheme.accent
                : (iconColor ?? AppTheme.textSecondary),
            size: 20),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? AppTheme.accent
                : (textColor ?? AppTheme.textPrimary),
          ),
        ),
        trailing: trailing,
      ),
    );
  }
}
