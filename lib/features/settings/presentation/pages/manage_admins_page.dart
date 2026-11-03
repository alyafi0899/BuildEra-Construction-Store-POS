import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/models/store_admin.dart';
import '../../../auth/providers/active_cashier_provider.dart';
import '../../../auth/providers/store_admins_provider.dart';
import '../../providers/settings_provider.dart';

class ManageAdminsPage extends ConsumerStatefulWidget {
  const ManageAdminsPage({super.key});

  @override
  ConsumerState<ManageAdminsPage> createState() => _ManageAdminsPageState();
}

class _ManageAdminsPageState extends ConsumerState<ManageAdminsPage> {
  bool _verifiedOwnerPin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptOwnerPin();
    });
  }

  Future<void> _promptOwnerPin() async {
    final settings = ref.read(settingsProvider);
    final correctPin = settings.securityPin;

    if (correctPin == null || correctPin.length < 4) {
      if (mounted) {
        showError(context, 'Silakan atur PIN Pemilik terlebih dahulu di Pengaturan.');
        Navigator.pop(context);
      }
      return;
    }

    final pinCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Verifikasi PIN Pemilik'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Akses ke halaman Kelola Admin khusus untuk Pemilik Toko. Masukkan PIN Pemilik Anda.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              autofocus: true,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'PIN Pemilik',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinCtrl.text == correctPin) {
                Navigator.pop(context, true);
              } else {
                showError(context, 'PIN Pemilik salah');
              }
            },
            child: const Text('VERIFIKASI'),
          ),
        ],
      ),
    );

    if (ok == true) {
      setState(() => _verifiedOwnerPin = true);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _showAdminFormDialog({StoreAdmin? admin}) async {
    final isEdit = admin != null;
    final nameCtrl = TextEditingController(text: admin?.name ?? '');
    final pinCtrl = TextEditingController();
    bool canEditPrice = admin?.canEditPrice ?? true;
    bool canGiveDiscount = admin?.canGiveDiscount ?? true;
    bool canVoid = admin?.canVoid ?? false;

    final repo = ref.read(storeAdminsRepositoryProvider);

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Ubah Admin Kasir' : 'Tambah Admin Kasir'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Admin / Kasir',
                    hintText: 'Contoh: Budi, Ani',
                  ),
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'PIN Kasir (4-6 Digit)',
                      counterText: '',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                const Text('Izin Akses Kasir:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                CheckboxListTile(
                  title: const Text('Bisa Ubah Harga Jual', style: TextStyle(fontSize: 13)),
                  value: canEditPrice,
                  onChanged: (v) => setDialogState(() => canEditPrice = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Bisa Beri Diskon', style: TextStyle(fontSize: 13)),
                  value: canGiveDiscount,
                  onChanged: (v) => setDialogState(() => canGiveDiscount = v ?? true),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                CheckboxListTile(
                  title: const Text('Bisa Hapus / Void Transaksi', style: TextStyle(fontSize: 13)),
                  value: canVoid,
                  onChanged: (v) => setDialogState(() => canVoid = v ?? false),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('BATAL'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  if (isEdit) {
                    await repo.updateAdminPermissions(
                      adminId: admin.id,
                      name: nameCtrl.text,
                      canEditPrice: canEditPrice,
                      canGiveDiscount: canGiveDiscount,
                      canVoid: canVoid,
                    );
                    if (context.mounted) {
                      Navigator.pop(dialogCtx);
                      showSuccess(context, 'Data admin berhasil diperbarui');
                    }
                  } else {
                    await repo.addAdmin(
                      name: nameCtrl.text,
                      pin: pinCtrl.text,
                      canEditPrice: canEditPrice,
                      canGiveDiscount: canGiveDiscount,
                      canVoid: canVoid,
                    );
                    if (context.mounted) {
                      Navigator.pop(dialogCtx);
                      showSuccess(context, 'Admin baru berhasil ditambahkan');
                    }
                  }
                } catch (e) {
                  if (context.mounted) showError(context, '$e');
                }
              },
              child: const Text('SIMPAN'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetPinDialog(StoreAdmin admin) async {
    final pinCtrl = TextEditingController();
    final repo = ref.read(storeAdminsRepositoryProvider);

    await showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Reset PIN "${admin.name}"'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'PIN Baru (4-6 Digit)',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await repo.resetAdminPin(
                  adminId: admin.id,
                  newPin: pinCtrl.text,
                );
                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }
                if (mounted) {
                  showSuccess(context, 'PIN "${admin.name}" berhasil direset');
                }
              } catch (e) {
                if (mounted) showError(context, '$e');
              }
            },
            child: const Text('RESET PIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_verifiedOwnerPin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kelola Admin')),
        body: const Center(child: AppLoading()),
      );
    }

    final admins = ref.watch(storeAdminsProvider).value ?? [];
    final activeAdmins = admins.where((a) => a.isActive).toList();
    final inactiveAdmins = admins.where((a) => !a.isActive).toList();
    final timeoutMinutes = ref.watch(autoLockTimeoutProvider);
    final repo = ref.read(storeAdminsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Admin Kasir'),
        actions: [
          IconButton(
            onPressed: () => _showAdminFormDialog(),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Tambah Admin Baru',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.accent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mode Multi-Kasir aktif otomatis jika ada minimal 1 admin aktif. '
                      'Nama kasir akan tercetak pada setiap struk dan laporan penjualan.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Auto-Lock Settings
            Card(
              child: ListTile(
                leading: const Icon(Icons.timer_rounded, color: AppTheme.accent),
                title: const Text('Kunci Otomatis Karena Tidak Ada Aktivitas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                subtitle: const Text('Sesi kasir otomatis terkunci jika perangkat tidak disentuh', style: TextStyle(fontSize: 12)),
                trailing: DropdownButton<int>(
                  value: timeoutMinutes,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Mati')),
                    DropdownMenuItem(value: 15, child: Text('15 Menit')),
                    DropdownMenuItem(value: 30, child: Text('30 Menit')),
                    DropdownMenuItem(value: 60, child: Text('60 Menit')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      ref.read(autoLockTimeoutProvider.notifier).setTimeoutMinutes(v);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Active Admins Section
            const Text('Admin / Kasir Aktif', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (activeAdmins.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Belum ada admin aktif. Mode kasir saat ini menggunakan profil Pemilik Toko.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              )
            else
              for (final admin in activeAdmins)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.success,
                      child: Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                    ),
                    title: Text(admin.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Izin: '
                      '${admin.canEditPrice ? 'Harga Jual' : ''}'
                      '${admin.canGiveDiscount ? (admin.canEditPrice ? ', Diskon' : 'Diskon') : ''}'
                      '${admin.canVoid ? (admin.canEditPrice || admin.canGiveDiscount ? ', Void' : 'Void') : ''}'
                      '${(!admin.canEditPrice && !admin.canGiveDiscount && !admin.canVoid) ? 'Hanya Baca' : ''}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (val) async {
                        if (val == 'edit') {
                          _showAdminFormDialog(admin: admin);
                        } else if (val == 'reset') {
                          _showResetPinDialog(admin);
                        } else if (val == 'deactivate') {
                          await repo.setAdminActive(adminId: admin.id, isActive: false);
                          if (context.mounted) showSuccess(context, 'Admin "${admin.name}" dinonaktifkan');
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Ubah Izin / Nama')),
                        PopupMenuItem(value: 'reset', child: Text('Reset PIN')),
                        PopupMenuItem(value: 'deactivate', child: Text('Nonaktifkan', style: TextStyle(color: AppTheme.danger))),
                      ],
                    ),
                  ),
                ),

            const SizedBox(height: 24),

            // Inactive Admins Section
            if (inactiveAdmins.isNotEmpty) ...[
              const Text('Admin Nonaktif', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
              const SizedBox(height: 10),
              for (final admin in inactiveAdmins)
                Card(
                  color: AppTheme.surfaceAlt,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppTheme.textMuted,
                      child: Icon(Icons.person_off_rounded, color: Colors.white, size: 20),
                    ),
                    title: Text(admin.name, style: const TextStyle(color: AppTheme.textMuted, decoration: TextDecoration.lineThrough)),
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await repo.setAdminActive(adminId: admin.id, isActive: true);
                          if (context.mounted) showSuccess(context, 'Admin "${admin.name}" diaktifkan kembali');
                        } catch (e) {
                          if (context.mounted) showError(context, '$e');
                        }
                      },
                      child: const Text('Aktifkan Kembali'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
