import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/auth_provider.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  Timer? _timer;
  bool _canResend = true;

  @override
  void initState() {
    super.initState();
    // Auto check verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.read(authRepositoryProvider).reloadUser();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resendEmail() async {
    if (!_canResend) return;
    try {
      await ref.read(authRepositoryProvider).sendVerificationEmail();
      setState(() => _canResend = false);
      if (mounted) showSuccess(context, 'Email verifikasi telah dikirim ulang.');
      Future.delayed(const Duration(seconds: 60), () {
        if (mounted) setState(() => _canResend = true);
      });
    } catch (e) {
      if (mounted) showError(context, 'Gagal mengirim email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 80, color: AppTheme.accent),
              const SizedBox(height: 24),
              Text('Verifikasi Email Anda', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              const Text(
                'Kami telah mengirimkan email verifikasi. Silakan cek inbox (atau folder spam) dan klik link verifikasi untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => ref.read(authRepositoryProvider).reloadUser(),
                  child: const Text('SAYA SUDAH VERIFIKASI'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _canResend ? _resendEmail : null,
                child: Text(_canResend ? 'Kirim Ulang Email' : 'Tunggu 1 menit untuk kirim ulang'),
              ),
              const Divider(height: 48),
              TextButton.icon(
                onPressed: () => ref.read(authRepositoryProvider).logout(),
                icon: const Icon(Icons.logout),
                label: const Text('Keluar dan Gunakan Akun Lain'),
                style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
