import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../../../core/sync/providers/connectivity_provider.dart';

class VerifyEmailPage extends ConsumerStatefulWidget {
  const VerifyEmailPage({super.key});

  @override
  ConsumerState<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends ConsumerState<VerifyEmailPage> {
  Timer? _timer;
  bool _canResend = true;
  bool _isChecking = false;

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

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    try {
      await ref.read(authRepositoryProvider).reloadUser();
      
      // The reloadUser() updates Firebase Auth state, 
      // which will eventually update authStateProvider.
      // But we can check current state immediately for feedback.
      final user = ref.read(authStateProvider).value;
      if (mounted) {
        if (user?.isEmailVerified ?? false) {
          showSuccess(context, 'Email berhasil diverifikasi! Mengalihkan...');
        } else {
          showError(context, 'Email belum terverifikasi. Silakan cek inbox Anda.');
        }
      }
    } catch (e) {
      if (mounted) showError(context, 'Gagal mengecek status: $e');
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
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
    final user = ref.watch(authStateProvider).value;
    final isOnline = ref.watch(isOnlineProvider);

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
              // Connectivity Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isOnline ? Colors.green : Colors.red, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isOnline ? Icons.wifi : Icons.wifi_off, size: 14, color: isOnline ? Colors.green : Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      isOnline ? 'ONLINE' : 'OFFLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Icon(Icons.mark_email_read_outlined, size: 80, color: AppTheme.accent),
              const SizedBox(height: 24),
              Text('Verifikasi Email Anda', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              if (user != null) ...[
                Text(
                  user.email,
                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
              ],
              const Text(
                'Kami telah mengirimkan email verifikasi. Silakan cek inbox (atau folder spam) dan klik link verifikasi untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking || !isOnline ? null : _checkVerification,
                  child: _isChecking 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('SAYA SUDAH VERIFIKASI'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _canResend && isOnline ? _resendEmail : null,
                child: Text(_canResend ? 'Kirim Ulang Email' : 'Tunggu 1 menit untuk kirim ulang'),
              ),
              const Divider(height: 48),
              TextButton.icon(
                onPressed: () async {
                  if (await showLogoutDialog(context)) {
                    if (mounted) ref.read(authRepositoryProvider).logout();
                  }
                },
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
