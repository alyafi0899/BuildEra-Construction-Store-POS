import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/auth_provider.dart';

class SetupPinPage extends ConsumerStatefulWidget {
  const SetupPinPage({super.key});

  @override
  ConsumerState<SetupPinPage> createState() => _SetupPinPageState();
}

class _SetupPinPageState extends ConsumerState<SetupPinPage> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePin() async {
    final isLoaded = ref.read(settingsLoadedProvider);
    final settings = ref.read(settingsProvider);

    if (!isLoaded || settings.isLoading) {
      showError(context, 'Pengaturan belum termuat, coba lagi sebentar');
      return;
    }

    if ((settings.securityPin?.length ?? 0) >= 4) {
      showError(context, 'PIN keamanan sudah diatur. Silakan gunakan menu Ubah PIN di Pengaturan.');
      return;
    }

    if (_pinCtrl.text.length < 4) {
      showError(context, 'PIN minimal 4 digit');
      return;
    }
    if (_pinCtrl.text != _confirmCtrl.text) {
      showError(context, 'Konfirmasi PIN tidak cocok');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi PIN Keamanan'),
        content: const Text(
          'PIN ini bersifat sangat rahasia dan HANYA boleh diketahui oleh PEMILIK TOKO. '
          'Apakah Anda yakin telah mengingat PIN ini dan menjaganya tetap rahasia?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('SAYA MENGERTI & SIMPAN'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final settings = ref.read(settingsProvider);
      final updated = settings.copyWith(
        securityPin: _pinCtrl.text,
      );
      
      await ref.read(settingsProvider.notifier).updateSettings(updated);
      
      if (mounted) {
        showSuccess(context, 'PIN Berhasil disimpan. Memasuki aplikasi...');
        // Small delay to let user see success before AuthGate switches
        await Future.delayed(const Duration(milliseconds: 500));
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal menyimpan PIN: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.security_rounded, size: 64, color: AppTheme.accent),
                const SizedBox(height: 24),
                Text('Setel PIN Keamanan', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 24),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'PENTING: KHUSUS PEMILIK',
                              style: TextStyle(
                                color: AppTheme.danger,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    const Text(
                      'PIN ini HANYA boleh diketahui oleh PEMILIK TOKO. '
                      'Digunakan untuk memproteksi data sensitif dan laporan toko.',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'PIN Baru (4-6 Digit)',
                  prefixIcon: Icon(Icons.lock_outline),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _confirmCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi PIN',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _savePin,
                  child: _loading ? const AppLoading() : const Text('SIMPAN & LANJUT'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  if (mounted) {
                    final logout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout?'),
                        content: const Text('Apakah Anda ingin keluar dari akun ini?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('TIDAK')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('YA, LOGOUT')),
                        ],
                      ),
                    );
                    if (logout == true) {
                      ref.read(authRepositoryProvider).logout();
                    }
                  }
                },
                child: const Text('Keluar (Logout)', style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
