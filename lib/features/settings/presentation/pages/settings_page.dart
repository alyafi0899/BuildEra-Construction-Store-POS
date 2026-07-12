import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
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
    final customerPayments = ref.read(debtPaymentsProvider((customerId: null, debtId: null))).asData?.value ?? [];
    final transactions = ref.read(transactionsProvider).asData?.value ?? [];
    final settings = ref.read(settingsProvider);

    debugPrint('DEBUG: Data counts - Products: ${products.length}, Transactions: ${transactions.length}');

    // 2. Immediate Feedback
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Membuka Folder Picker...'), duration: Duration(seconds: 1)),
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
        setState(() {
          _bankAccounts = List.from(next.bankAccounts);
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
                onPressed: () => ref.read(authRepositoryProvider).logout(),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Keluar (Logout)'),
                style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger)),
              ),
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Simpan Perubahan'),
              ),
            ],
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
                            Expanded(child: _buildInput('Nama Toko / Usaha', _businessNameCtrl, Icons.store_rounded)),
                            const SizedBox(width: 20),
                            Expanded(child: _buildInput('Nama Pemilik', _ownerNameCtrl, Icons.person_rounded)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: _buildInput('Nomor Telepon', _phoneCtrl, Icons.phone_rounded)),
                            const SizedBox(width: 20),
                            Expanded(child: _buildInput('Email Bisnis', _emailCtrl, Icons.business_outlined)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInput('Alamat Toko', _addressCtrl, Icons.location_on_rounded, maxLines: 2),
                        const SizedBox(height: 20),
                        _buildInput('Deskripsi Toko', _descriptionCtrl, Icons.description_rounded, maxLines: 3),
                        
                        const SizedBox(height: 40),
                        const _SectionTitle(title: 'Metode Pembayaran Digital'),
                        const SizedBox(height: 16),
                        _buildQrisSetting(ref),

                        const SizedBox(height: 40),
                        const _SectionTitle(title: 'Data & Backup'),
                        const SizedBox(height: 16),
                        AppCard(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.download_for_offline_rounded, color: AppTheme.accent),
                                title: const Text('Backup Keseluruhan (Excel)', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: const Text('Download 3 file Excel: Master Produk, Piutang Pelanggan, dan Analitik Penjualan'),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => _handleFullBackup(ref),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 40),
                        const _SectionTitle(title: 'Pengaturan Tampilan & Tema'),
                        const SizedBox(height: 16),
                        //_buildThemeSelector(ref),
                        const SizedBox(height: 16),
                        _buildAppSettings(ref),

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

  // Widget _buildThemeSelector(WidgetRef ref) {
  //   final currentMode = ref.watch(themeProvider);
  //   final notifier = ref.read(themeProvider.notifier);
  //   final colorScheme = Theme.of(context).colorScheme;
  //
  //   return Container(
  //     padding: const EdgeInsets.all(20),
  //     decoration: BoxDecoration(
  //       color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
  //       borderRadius: BorderRadius.circular(16),
  //       border: Border.all(color: colorScheme.outline),
  //     ),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Row(
  //           children: [
  //             Icon(Icons.palette_rounded, size: 20, color: colorScheme.primary),
  //             const SizedBox(width: 12),
  //             const Text('Tema Warna Aplikasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
  //           ],
  //         ),
  //         const SizedBox(height: 20),
  //         GridView.count(
  //           shrinkWrap: true,
  //           physics: const NeverScrollableScrollPhysics(),
  //           crossAxisCount: 3,
  //           mainAxisSpacing: 12,
  //           crossAxisSpacing: 12,
  //           childAspectRatio: 2.2,
  //           children: AppThemeMode.values.map((mode) {
  //             final isSelected = currentMode == mode;
  //             final themeData = AppThemes.getTheme(mode);
  //
  //             return InkWell(
  //               onTap: () => notifier.setTheme(mode),
  //               borderRadius: BorderRadius.circular(12),
  //               child: AnimatedContainer(
  //                 duration: const Duration(milliseconds: 200),
  //                 decoration: BoxDecoration(
  //                   color: themeData.scaffoldBackgroundColor,
  //                   borderRadius: BorderRadius.circular(12),
  //                   border: Border.all(
  //                     color: isSelected ? colorScheme.primary : colorScheme.outline,
  //                     width: isSelected ? 2 : 1,
  //                   ),
  //                   boxShadow: isSelected ? [
  //                     BoxShadow(color: colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
  //                   ] : [],
  //                 ),
  //                 child: Stack(
  //                   children: [
  //                     Padding(
  //                       padding: const EdgeInsets.symmetric(horizontal: 16),
  //                       child: Row(
  //                         children: [
  //                           Container(
  //                             width: 24,
  //                             height: 24,
  //                             decoration: BoxDecoration(
  //                               color: themeData.colorScheme.primary,
  //                               shape: BoxShape.circle,
  //                               border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
  //                             ),
  //                           ),
  //                           const SizedBox(width: 12),
  //                           Expanded(
  //                             child: Text(
  //                               _getThemeLabel(mode),
  //                               style: TextStyle(
  //                                 fontSize: 12,
  //                                 fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
  //                                 color: themeData.colorScheme.onSurface,
  //                               ),
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                     if (isSelected)
  //                       Positioned(
  //                         top: 8, right: 8,
  //                         child: Icon(Icons.check_circle_rounded, size: 16, color: colorScheme.primary),
  //                       ),
  //                   ],
  //                 ),
  //               ),
  //             );
  //           }).toList(),
  //         ),
  //       ],
  //     ),
  //   );
  // }
  //
  // String _getThemeLabel(AppThemeMode mode) {
  //   switch (mode) {
  //     case AppThemeMode.darkOrange: return 'Dark Orange';
  //     case AppThemeMode.lightBlue: return 'Light Blue';
  //     case AppThemeMode.lightBlueOrange: return 'Blue + Orange';
  //     case AppThemeMode.lightOrangeBlue: return 'Orange + Blue';
  //     case AppThemeMode.lightOrangeGreen: return 'Orange + Green';
  //     case AppThemeMode.lightOrange: return 'Light Orange';
  //   }
  // }

  Widget _buildQrisSetting(WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.qr_code_2_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Barcode QRIS Toko', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Preview Box (5:8 Aspect Ratio)
              Container(
                width: 120,
                height: 192, // 120 * 8 / 5
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: settings.qrisImagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(File(settings.qrisImagePath!), fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.qr_code_scanner_rounded, size: 32, color: colorScheme.onSurface.withValues(alpha: 0.2)),
                          const SizedBox(height: 8),
                          Text('Belum ada', style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                        ],
                      ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upload Barcode QRIS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    const Text('Gambar ini akan ditampilkan di layar kasir dan layar pelanggan saat memilih metode pembayaran QRIS.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final bytes = await ImageHelper.pickAndCropImage(context);
                            if (bytes != null) {
                              final user = ref.read(authStateProvider).value;
                              if (user == null) return;
                              final processed = await ImageHelper.processImage(bytes);
                              final path = await ImageHelper.saveLocally(user.uid, 'qris_barcode.jpg', processed, subFolder: 'store_assets');
                              if (path != null) {
                                final updated = settings.copyWith(qrisImagePath: path);
                                ref.read(settingsProvider.notifier).updateSettings(updated);
                                if (mounted) {
                                  showSuccess(context, 'Barcode QRIS berhasil diperbarui');
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.upload_rounded, size: 18),
                          label: const Text('Pilih Gambar'),
                        ),
                        if (settings.qrisImagePath != null) ...[
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              final updated = settings.copyWith(qrisImagePath: null);
                              ref.read(settingsProvider.notifier).updateSettings(updated);
                              showSuccess(context, 'Barcode QRIS dihapus');
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 18),
                            label: const Text('Hapus'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger, side: const BorderSide(color: AppTheme.danger)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Rekomendasi: Gambar vertikal dengan perbandingan 5:8 untuk hasil terbaik.',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.4), fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppSettings(WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _buildSettingRow(
            icon: Icons.fullscreen_rounded,
            label: 'Layar Penuh (Full Screen)',
            child: Switch.adaptive(
              value: appSettings.isFullScreen,
              onChanged: (v) => notifier.setFullScreen(v),
              activeTrackColor: AppTheme.accent,
            ),
          ),
          const Divider(height: 32),
          _buildSettingRow(
            icon: Icons.monitor_rounded,
            label: 'Tampilan Pelanggan (Dual Display)',
            child: Row(
              children: [
                if (appSettings.isCustomerDisplayEnabled)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: OutlinedButton.icon(
                      onPressed: () => _openCustomerDisplayUrl(context),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Buka Layar', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                Switch.adaptive(
                  value: appSettings.isCustomerDisplayEnabled,
                  onChanged: (v) => notifier.setCustomerDisplay(v),
                  activeTrackColor: AppTheme.accent,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({required IconData icon, required String label, required Widget child}) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14)),
        const Spacer(),
        child,
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

  void _openCustomerDisplayUrl(BuildContext context) async {
    try {
      final user = ref.read(authStateProvider).value;
      final args = ['multi_window', 'uid=${user?.uid ?? 'unknown'}'];
      
      // Use detached mode to ensure process independence on Windows
      await Process.start(
        Platform.resolvedExecutable, 
        args,
        mode: ProcessStartMode.detached,
      );
      
      if (context.mounted) {
        showSuccess(context, 'Membuka jendela pelanggan...');
      }
    } catch (e) {
      if (context.mounted) {
        showError(context, 'Gagal membuka jendela: $e');
      }
    }
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
