import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pin_unlock_provider.dart';

class EnterPinPage extends ConsumerStatefulWidget {
  const EnterPinPage({super.key});

  @override
  ConsumerState<EnterPinPage> createState() => _EnterPinPageState();
}

class _EnterPinPageState extends ConsumerState<EnterPinPage> {
  final _pinCtrl = TextEditingController();
  bool _error = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  void _unlock() {
    final correctPin = ref.read(settingsProvider).securityPin;
    if (_pinCtrl.text == correctPin) {
      ref.read(pinUnlockProvider.notifier).unlock();
    } else {
      setState(() {
        _error = true;
        _pinCtrl.clear();
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _error = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _error ? AppTheme.danger : AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_person_rounded, size: 64, color: AppTheme.accent),
              const SizedBox(height: 24),
              const Text(
                'Akses Terkunci',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Masukkan PIN Keamanan Toko Anda untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 32, letterSpacing: 16, color: Colors.white),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                   if (v.length >= 4) {
                     // Auto-verify if typical length reached
                     // But we have a button for clarity
                   }
                },
                onSubmitted: (_) => _unlock(),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.1)),
                  enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.border)),
                  focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.accent)),
                ),
              ),
              if (_error) ...[
                const SizedBox(height: 16),
                const Text(
                  'PIN Salah! Silakan coba lagi.',
                  style: TextStyle(color: AppTheme.danger, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _unlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('BUKA AKSES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () async {
                  if (await showLogoutDialog(context)) {
                    if (mounted) ref.read(authRepositoryProvider).logout();
                  }
                },
                child: const Text('Keluar Akun', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
