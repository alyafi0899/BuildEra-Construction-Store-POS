import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/image_helper.dart';
import '../../../../core/utils/backup_helper.dart';
import '../../../../core/sync/services/local_database.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/store_settings.dart';
import '../../providers/settings_provider.dart';
import '../widgets/printing_settings_widget.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';
import '../../../subscription/providers/subscription_provider.dart';
import '../../../../shared/widgets/security_gate.dart';
import '../../../products/providers/product_provider.dart';
import '../../../payment/providers/transaction_provider.dart';
import '../../../inventory/providers/restock_provider.dart';
import '../../../inventory/providers/bill_payment_provider.dart';
import '../../../debts/providers/debt_repository.dart';
import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/localization_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../../../core/sync/providers/initial_sync_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int? _selectedCategory; // null = Menu List View; 0..5 = Full-Page Category Detail
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
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) return;

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

  Future<void> _handleBackupExcel() async {
    requirePin(context, ref, () async {
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mengambil data untuk Master Backup Excel...'),
              duration: Duration(seconds: 2),
            ),
          );
        }

        final products = ref.read(productsProvider).asData?.value ?? [];
        final transactions = ref.read(transactionsProvider).asData?.value ?? [];
        final customers = ref.read(customersProvider).asData?.value ?? [];
        final restocks = ref.read(restockHistoryProvider).asData?.value ?? [];
        final billPayments = ref.read(billPaymentsProvider).asData?.value ?? [];

        final debtRepo = ref.read(debtRepositoryProvider);
        final customerDebts = await debtRepo.getDebts();
        final customerPayments = await debtRepo.getPayments();

        final settings = ref.read(settingsProvider);

        if (!mounted) return;
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
      } catch (e) {
        if (mounted) showError(context, 'Gagal menyusun backup: $e');
      }
    });
  }

  Future<void> _handleResetAllData() async {
    final settings = ref.read(settingsProvider);
    final hasPin =
        settings.securityPin != null && settings.securityPin!.isNotEmpty;

    if (!hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Atur PIN Keamanan terlebih dahulu sebelum mereset data toko!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      setState(() => _selectedCategory = 4);
      return;
    }

    requirePin(context, ref, () async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 28),
              SizedBox(width: 10),
              Text('HAPUS SEMUA DATA?'),
            ],
          ),
          content: const Text(
            'Tindakan ini akan menghapus SELURUH data operasional toko (produk, transaksi, piutang, restock, dll.) dari cache lokal dan server secara permanen!\n\nYakin ingin melanjutkan?',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Iya, Hapus Seluruh Data'),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        try {
          final user = ref.read(authStateProvider).value;
          if (user != null) {
            // 1. Clear Local Hive Database
            await LocalDatabase.clearUserCache(user.uid);

            // 2. Clear Remote Data if Online
            final supabase = ref.read(supabaseClientProvider);
            final collections = [
              'products',
              'transactions',
              'customers',
              'debts',
              'debt_payments',
              'suppliers',
              'shipping_services',
              'restock_history',
              'bill_payments',
              'barcode_history'
            ];
            for (final col in collections) {
              try {
                await supabase.from(col).delete().eq('user_id', user.uid);
              } catch (_) {}
            }

            // 3. Refresh Settings and Providers
            await ref.read(settingsProvider.notifier).refreshFromRemote();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Seluruh data operasional berhasil di-reset.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        } catch (e) {
          if (mounted) showError(context, 'Gagal menghapus data: $e');
        }
      }
    });
  }

  void _showLanguageSelectionDialog(BuildContext context, WidgetRef ref) {
    final currentLang = ref.read(appSettingsProvider).appLanguage;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.language_rounded, color: AppTheme.accent),
            SizedBox(width: 12),
            Text('Pilih Bahasa / Select Language'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLanguage.values.map((lang) {
            final isSelected = lang == currentLang;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
                title: Text(lang.displayName,
                    style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                trailing: isSelected
                    ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent)
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppTheme.accent : AppTheme.border,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(appSettingsProvider.notifier).setLanguage(lang);
                },
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal / Cancel'),
          ),
        ],
      ),
    );
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
              Navigator.pop(context);
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

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: _selectedCategory == null
            ? _buildCategoryListView()
            : _buildCategoryDetailView(_selectedCategory!),
      ),
    );
  }

  // ── 1. Categorized Settings Menu List View ──────────────────────────────────

  Widget _buildCategoryListView() {
    return Column(
      children: [
        PageHeader(
          title: 'Pengaturan POS',
          subtitle: 'Pilih kategori pengaturan untuk dikonfigurasi',
          icon: Icons.settings_rounded,
          actions: [
            IconButton(
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout_rounded, color: AppTheme.danger),
              tooltip: 'Keluar / Logout',
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _categoryGroupHeader('FITUR & OPERASIONAL'),
              _CategoryCard(
                icon: Icons.tune_rounded,
                iconColor: AppTheme.accent,
                title: 'Manajemen Fitur POS',
                subtitle:
                    'Aktifkan atau nonaktifkan menu Kasir, Produk, Pembelian, Piutang, Tagihan, Barcode, & Analitik',
                onTap: () {
                  requirePin(context, ref, () {
                    setState(() => _selectedCategory = 0);
                  });
                },
              ),
              const SizedBox(height: 20),

              _categoryGroupHeader('PROFIL & BISNIS'),
              _CategoryCard(
                icon: Icons.store_rounded,
                iconColor: Colors.blueAccent,
                title: 'Informasi Toko & Perusahaan',
                subtitle:
                    'Nama bisnis, pemilik, nomor HP/WA, email, alamat lengkap, & slogan toko',
                onTap: () => setState(() => _selectedCategory = 1),
              ),
              const SizedBox(height: 10),
              _CategoryCard(
                icon: Icons.account_balance_rounded,
                iconColor: Colors.teal,
                title: 'Metode Pembayaran & QRIS',
                subtitle:
                    'Rekening bank transfer untuk nota pembayaran & foto gambar QRIS toko',
                onTap: () => setState(() => _selectedCategory = 2),
              ),
              const SizedBox(height: 20),

              _categoryGroupHeader('CETAK & STRUK'),
              _CategoryCard(
                icon: Icons.print_rounded,
                iconColor: Colors.orangeAccent,
                title: 'Printer & Desain Struk',
                subtitle:
                    'Konfigurasi printer Bluetooth/WiFi, lebar kertas (58/80mm), margin, & desain nota',
                onTap: () => setState(() => _selectedCategory = 3),
              ),
              const SizedBox(height: 20),

              _categoryGroupHeader('KEAMANAN'),
              _CategoryCard(
                icon: Icons.security_rounded,
                iconColor: Colors.purpleAccent,
                title: 'Keamanan & PIN Admin',
                subtitle:
                    'Proteksi PIN admin untuk akses halaman analitik, produk, & harga modal',
                onTap: () => setState(() => _selectedCategory = 4),
              ),
              const SizedBox(height: 20),

              _categoryGroupHeader('AKUN & SISTEM'),
              _CategoryCard(
                icon: Icons.stars_rounded,
                iconColor: Colors.amber,
                title: 'Paket Langganan Premium',
                subtitle:
                    'Status paket langganan aktif dan akses ke fitur-fitur POS premium',
                trailingBadge: ref.watch(isPremiumProvider) ? 'PREMIUM' : 'GRATIS',
                onTap: () => setState(() => _selectedCategory = 5),
              ),
              const SizedBox(height: 10),
              _CategoryCard(
                icon: Icons.language_rounded,
                iconColor: Colors.cyan,
                title: ref.watch(appStringsProvider).languageSettings,
                subtitle: ref.watch(appStringsProvider).selectLanguage,
                trailingBadge: '${ref.watch(appSettingsProvider).appLanguage.flag} ${ref.watch(appSettingsProvider).appLanguage.displayName}',
                onTap: () => _showLanguageSelectionDialog(context, ref),
              ),
              const SizedBox(height: 20),

              _categoryGroupHeader('PEMELIHARAAN & DATA'),
              _CategoryCard(
                icon: Icons.cloud_download_rounded,
                iconColor: AppTheme.accent,
                title: 'Sinkronisasi & Unduh Data Cloud',
                subtitle:
                    'Unduh dan sinkronkan data produk, transaksi, & pengaturan dari cloud Supabase',
                onTap: () async {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Memulai sinkronisasi data dari cloud...'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  try {
                    await ref.read(initialSyncProvider.notifier).triggerManualSync();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Sinkronisasi data cloud selesai.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal sinkronisasi: $e'),
                          backgroundColor: AppTheme.danger,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              _CategoryCard(
                icon: Icons.table_chart_rounded,
                iconColor: Colors.green,
                title: 'Backup Data ke Excel',
                subtitle:
                    'Ekspor seluruh data produk, transaksi, piutang, & restock ke 1 file Master Excel',
                onTap: _handleBackupExcel,
              ),
              const SizedBox(height: 20),

              _categoryGroupHeader('AREA BAHAYA'),
              _CategoryCard(
                icon: Icons.delete_forever_rounded,
                iconColor: AppTheme.danger,
                title: 'Reset & Hapus Seluruh Data Toko',
                subtitle:
                    'Hapus seluruh data produk, transaksi, piutang, dan riwayat operasional secara permanen',
                isDanger: true,
                onTap: _handleResetAllData,
              ),
              const SizedBox(height: 10),

              _CategoryCard(
                icon: Icons.logout_rounded,
                iconColor: AppTheme.danger,
                title: 'Keluar / Logout Akun',
                subtitle: 'Sesi login aktif dan keluar dari akun saat ini',
                isDanger: true,
                onTap: () => _handleLogout(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryGroupHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w900,
          fontSize: 11,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }

  // ── 2. Full-Page Category Detail View ──────────────────────────────────────

  Widget _buildCategoryDetailView(int categoryIndex) {
    final titles = [
      'Manajemen Fitur POS',
      'Informasi Toko & Perusahaan',
      'Metode Pembayaran & QRIS',
      'Printer & Desain Struk',
      'Keamanan & PIN Admin',
      'Paket Langganan Premium',
    ];

    return Column(
      children: [
        // Category Top Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: AppTheme.surface,
          child: Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedCategory = null),
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.accent),
                tooltip: 'Kembali ke Daftar Pengaturan',
              ),
              const SizedBox(width: 8),
              Text(
                titles[categoryIndex],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (categoryIndex != 5) ...[
                ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Simpan'),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.border),

        // Body Content
        Expanded(
          child: categoryIndex == 5
              ? const SubscriptionPage()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (categoryIndex == 0) _buildFeatureManagementSection(),
                        if (categoryIndex == 1) _buildStoreSection(),
                        if (categoryIndex == 2) _buildPaymentSection(),
                        if (categoryIndex == 3) _buildPrintingSection(),
                        if (categoryIndex == 4) _buildSecuritySection(),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── Section 0: Manajemen Fitur POS ─────────────────────────────────────────

  Widget _buildFeatureManagementSection() {
    final settings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Aktifkan / Nonaktifkan Fitur POS'),
        const SizedBox(height: 8),
        const Text(
          'Atur fitur mana saja yang tampil di navigasi utama. Fitur yang dinonaktifkan akan tersembunyi dari menu navigasi.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 24),
        _featureToggleCard(
          title: 'Kasir Penjualan',
          subtitle: 'Modul transaksi kasir, scanner barcode, keranjang, & pembayaran',
          icon: Icons.point_of_sale_rounded,
          value: settings.enableCashier,
          onChanged: (v) {
            requirePin(context, ref, () async {
              await ref.read(settingsProvider.notifier).updateSettings(
                  settings.copyWith(enableCashier: v));
            });
          },
        ),
        const SizedBox(height: 12),
        _featureToggleCard(
          title: 'Manajemen Produk & Stok',
          subtitle: 'Katalog barang, kategori, harga jual/modal, & penyesuaian stok',
          icon: Icons.inventory_2_rounded,
          value: settings.enableProducts,
          onChanged: (v) {
            requirePin(context, ref, () async {
              await ref.read(settingsProvider.notifier).updateSettings(
                  settings.copyWith(enableProducts: v));
            });
          },
        ),
        const SizedBox(height: 12),
        _featureToggleCard(
          title: 'Pembelian & Restok Supplier',
          subtitle: 'Pencatatan barang masuk dari supplier, ongkir, & riwayat restok',
          icon: Icons.local_shipping_rounded,
          value: settings.enablePurchase,
          onChanged: (v) {
            requirePin(context, ref, () async {
              await ref.read(settingsProvider.notifier).updateSettings(
                  settings.copyWith(enablePurchase: v));
            });
          },
        ),
        const SizedBox(height: 12),
        _featureToggleCard(
          title: 'Riwayat Transaksi Penjualan',
          subtitle: 'Daftar semua nota transaksi selesai, cetak ulang, & refund',
          icon: Icons.receipt_long_rounded,
          value: settings.enableTransactions,
          onChanged: (v) {
            requirePin(context, ref, () async {
              await ref.read(settingsProvider.notifier).updateSettings(
                  settings.copyWith(enableTransactions: v));
            });
          },
        ),
        const SizedBox(height: 12),
        _featureToggleCard(
          title: 'Piutang & Pelanggan',
          subtitle: 'Pencatatan bon piutang, riwayat cicilan, & data pelanggan',
          icon: Icons.account_balance_wallet_rounded,
          value: settings.enableDebts,
          onChanged: (v) {
            requirePin(context, ref, () async {
              await ref.read(settingsProvider.notifier).updateSettings(
                  settings.copyWith(enableDebts: v));
            });
          },
        ),
        const SizedBox(height: 12),
        _featureToggleCard(
          title: 'Tagihan & Operasional Toko',
          subtitle: 'Pencatatan pengeluaran operasional toko, listrik, gaji, & sewa',
          icon: Icons.receipt_rounded,
          value: settings.enableBills,
          onChanged: (v) {
            requirePin(context, ref, () async {
              await ref.read(settingsProvider.notifier).updateSettings(
                  settings.copyWith(enableBills: v));
            });
          },
        ),
        const SizedBox(height: 12),
        _featureToggleCard(
          title: 'Cetak Label & Barcode',
          subtitle: 'Desain & pencetakan label barcode produk ke printer thermal/label',
          icon: Icons.qr_code_2_rounded,
          value: settings.enableBarcode,
          onChanged: (v) {
            requirePin(context, ref, () async {
              await ref.read(settingsProvider.notifier).updateSettings(
                  settings.copyWith(enableBarcode: v));
            });
          },
        ),
        const SizedBox(height: 12),
        _featureToggleCard(
          title: 'Laporan & Analitik',
          subtitle: 'Grafik omset, laba rugi, barang terlaris, & laporan keuangan',
          icon: Icons.bar_chart_rounded,
          value: settings.enableAnalytics,
          onChanged: (v) {
            requirePin(context, ref, () async {
              await ref.read(settingsProvider.notifier).updateSettings(
                  settings.copyWith(enableAnalytics: v));
            });
          },
        ),
      ],
    );
  }

  Widget _featureToggleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: value ? AppTheme.accent.withValues(alpha: 0.5) : AppTheme.border),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.accent,
        title: Row(
          children: [
            Icon(icon, size: 20, color: value ? AppTheme.accent : AppTheme.textMuted),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4, left: 30),
          child: Text(subtitle,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ),
      ),
    );
  }

  // ── Section 1: Store Info ──────────────────────────────────────────────────

  Widget _buildStoreSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Identitas Bisnis'),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;
            if (isCompact) {
              return Column(
                children: [
                  Center(child: _buildLogoPicker()),
                  const SizedBox(height: 20),
                  _LocalTextField(
                    controller: _businessNameCtrl,
                    label: 'Nama Toko / Perusahaan',
                    prefixIcon: const Icon(Icons.business_rounded),
                    validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 16),
                  _LocalTextField(
                    controller: _ownerNameCtrl,
                    label: 'Nama Pemilik',
                    prefixIcon: const Icon(Icons.person_rounded),
                  ),
                ],
              );
            }
            return Row(
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
            );
          },
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                children: [
                  _LocalTextField(
                    controller: _phoneCtrl,
                    label: 'Nomor Telepon / WhatsApp',
                    prefixIcon: const Icon(Icons.phone_rounded),
                  ),
                  const SizedBox(height: 16),
                  _LocalTextField(
                    controller: _emailCtrl,
                    label: 'Email Bisnis',
                    prefixIcon: const Icon(Icons.email_rounded),
                  ),
                ],
              );
            }
            return Row(
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
            );
          },
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

  // ── Section 2: Payment & QRIS ───────────────────────────────────────────────

  Widget _buildPaymentSection() {
    final settings = ref.watch(settingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: _SectionTitle(title: 'Rekening Bank Transfer'),
            ),
            ElevatedButton.icon(
              onPressed: _showAddBankDialog,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Tambah Bank'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_bankAccounts.isEmpty)
          const EmptyState(
            icon: Icons.account_balance_outlined,
            title: 'Belum ada rekening bank',
            subtitle:
                'Tambahkan nomor rekening agar dapat ditampilkan pada nota pembayaran',
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _bankAccounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final bank = _bankAccounts[index];
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_rounded,
                          color: AppTheme.accent),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bank.bankName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${bank.accountNumber} a.n ${bank.accountHolder}',
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
                      onPressed: () {
                        setState(() {
                          _bankAccounts.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        const SizedBox(height: 32),
        const Divider(height: 1),
        const SizedBox(height: 32),

        const _SectionTitle(title: 'QRIS Pembayaran'),
        const SizedBox(height: 8),
        const Text(
          'Upload gambar QRIS toko Anda agar pelanggan dapat melakukan pembayaran dengan scan QRIS.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 20),
        FutureBuilder<String?>(
          future: ImageHelper.resolveLocalPath(settings.qrisImagePath),
          builder: (context, snapshot) {
            final resolved = snapshot.data;
            final hasQris = resolved != null && resolved.isNotEmpty;

            return Row(
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: hasQris
                      ? Image.file(
                          File(resolved),
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                              Icons.broken_image_rounded,
                              size: 40,
                              color: AppTheme.textMuted),
                        )
                      : const Icon(Icons.qr_code_2_rounded,
                          size: 48, color: AppTheme.textMuted),
                ),
                const SizedBox(width: 24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickQrisImage,
                      icon: const Icon(Icons.upload_file_rounded),
                      label: Text(hasQris ? 'UBAH GAMBAR QRIS' : 'UPLOAD QRIS'),
                    ),
                    if (hasQris) ...[
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final current = ref.read(settingsProvider);
                          await ref
                              .read(settingsProvider.notifier)
                              .updateSettings(
                                  current.copyWith(qrisImagePath: null));
                          if (context.mounted) {
                            showSuccess(context, 'Gambar QRIS terhapus');
                          }
                        },
                        icon: const Icon(Icons.delete_outline_rounded,
                            color: AppTheme.danger),
                        label: const Text('Hapus QRIS',
                            style: TextStyle(color: AppTheme.danger)),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
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
            'Foto QRIS tersimpan di perangkat. Sinkronisasi cloud gagal.');
      }
    }
  }

  void _showAddBankDialog() {
    final bankNameCtrl = TextEditingController();
    final accNumCtrl = TextEditingController();
    final accHolderCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Rekening Bank'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: bankNameCtrl,
                decoration: const InputDecoration(
                    labelText: 'Nama Bank (e.g BCA, Mandiri)'),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: accNumCtrl,
                decoration: const InputDecoration(labelText: 'Nomor Rekening'),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: accHolderCtrl,
                decoration:
                    const InputDecoration(labelText: 'Nama Pemilik Rekening'),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
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
                setState(() {
                  _bankAccounts.add(BankAccount(
                    bankName: bankNameCtrl.text.trim(),
                    accountNumber: accNumCtrl.text.trim(),
                    accountHolder: accHolderCtrl.text.trim(),
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  // ── Section 3: Printing Settings ───────────────────────────────────────────

  Widget _buildPrintingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          onInvoicePrinterChanged: (v) => setState(() => _invoicePrinterUrl = v),
        ),
      ],
    );
  }

  // ── Section 4: Security ────────────────────────────────────────────────────

  Widget _buildSecuritySection() {
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

  Widget _buildPinField(TextEditingController controller) {
    return TextFormField(
      controller: controller,
      autofocus: true,
      obscureText: true,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(
          fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        counterText: '',
        hintText: '••••••',
        border: OutlineInputBorder(),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'PIN tidak boleh kosong';
        if (v.length < 4) return 'PIN minimal 4 digit';
        return null;
      },
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

                  navigator.pop();
                  navigator.pop();
                  _showPinDialog(false);
                  showSuccess(this.context,
                      'Verifikasi sukses! Silakan buat PIN baru.');
                } catch (e) {
                  if (!mounted || !dialogContext.mounted) return;
                  navigator.pop();
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

  void _showLocalLoadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const AppLoading(),
            const SizedBox(width: 20),
            Text(msg),
          ],
        ),
      ),
    );
  }
}

// ── Category Card Widget ────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingBadge;
  final bool isDanger;

  const _CategoryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingBadge,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDanger
                    ? AppTheme.danger.withValues(alpha: 0.3)
                    : AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDanger ? AppTheme.danger : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (trailingBadge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trailingBadge!,
                    style: const TextStyle(
                        color: AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: isDanger ? AppTheme.danger : AppTheme.textMuted,
              ),
            ],
          ),
        ),
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
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
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
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: prefixIcon,
      ),
      validator: validator,
    );
  }
}
