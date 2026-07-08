import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/shared/widgets/common_widgets.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mark_email_read_outlined, size: 80, color: colorScheme.primary),
              const SizedBox(height: 24),
              Text('Verifikasi Email Anda', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(
                'Kami telah mengirimkan email verifikasi. Silakan cek inbox (atau folder spam) dan klik link verifikasi untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6)),
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
                style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
