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
    if (_pinCtrl.text.length < 4) {
      showError(context, 'PIN minimal 4 digit');
      return;
    }
    if (_pinCtrl.text != _confirmCtrl.text) {
      showError(context, 'Konfirmasi PIN tidak cocok');
      return;
    }

    setState(() => _loading = true);
    try {
      final settings = ref.read(settingsProvider);
      final updated = settings.copyWith(securityPin: _pinCtrl.text);
      await ref.read(settingsProvider.notifier).updateSettings(updated);
      // AuthGate will rebuild and see the PIN is set
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security_rounded, size: 64, color: AppTheme.accent),
              const SizedBox(height: 24),
              Text('Setel PIN Keamanan', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Buat PIN Keamanan untuk melindungi data finansial dan laporan toko Anda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
                onPressed: () => ref.read(authRepositoryProvider).logout(),
                child: const Text('Keluar (Logout)', style: TextStyle(color: AppTheme.danger)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
