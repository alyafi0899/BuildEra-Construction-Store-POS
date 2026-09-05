import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../pages/login_page.dart';
import '../pages/verify_email_page.dart';
import '../pages/setup_pin_page.dart';
import '../../../../main.dart'; 
import '../../../../shared/widgets/splash_screen.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../core/sync/providers/initial_sync_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final registrationEmail = ref.watch(registrationEmailProvider);

    // Listen to sync state to show dialog
    ref.listen(initialSyncProvider, (prev, next) {
      if (next.isInitialSyncDone == false && !_dialogShown && !next.isSyncing && next.error == null) {
         _showSyncPrompt();
      }
    });

    if (registrationEmail != null) {
      return const VerifyEmailPage();
    }

    return authState.when(
      data: (user) {
        if (user == null) {
          _dialogShown = false;
          return const LoginPage();
        }
        
        if (!user.isEmailVerified) {
          return const VerifyEmailPage();
        }

        final syncState = ref.watch(initialSyncProvider);
        if (!syncState.isStatusLoaded) {
           return const SplashScreen(status: 'Memuat Status Sinkronisasi...');
        }

        // --- STABILITY FIX: Wait for settings to load ---
        final settings = ref.watch(settingsProvider);
        if (settings.isLoading) {
           return const SplashScreen(status: 'Memuat Pengaturan...');
        }
        
        // If settings are loaded and businessName is empty, it's a new account
        if (settings.businessName.isEmpty) {
           return const SetupPinPage();
        }

        return const MainShell();
      },
      loading: () => const SplashScreen(status: 'Menghubungkan ke Server...'),
      error: (e, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 48),
              const SizedBox(height: 16),
              Text('Terjadi kesalahan sistem: $e'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => ref.read(authRepositoryProvider).logout(),
                child: const Text('Kembali ke Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSyncPrompt() {
    setState(() => _dialogShown = true);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _SyncPromptDialog(),
    );
  }
}

class _SyncPromptDialog extends ConsumerWidget {
  const _SyncPromptDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(initialSyncProvider);

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        syncState.isInitialSyncDone ? 'Sinkronisasi Selesai' : 'Sinkronisasi Data',
        style: const TextStyle(color: Colors.white),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncState.isInitialSyncDone)
            const Text(
              'Seluruh data Anda telah berhasil diunduh dari cloud. Anda sekarang dapat menggunakan aplikasi dengan data terbaru.',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            const Text(
              'Perangkat baru terdeteksi. Silakan unduh data Anda dari cloud untuk melanjutkan.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          if (syncState.isSyncing) ...[
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: syncState.progress,
              backgroundColor: AppTheme.surfaceAlt,
              color: AppTheme.accent,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 12),
            Text(
              syncState.currentTask ?? 'Mengunduh data...', 
              style: const TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
          if (syncState.error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Text('Error: ${syncState.error}', style: const TextStyle(color: AppTheme.danger, fontSize: 11)),
            ),
          ],
        ],
      ),
      actions: [
        if (!syncState.isSyncing && !syncState.isInitialSyncDone)
          TextButton(
            onPressed: () => ref.read(initialSyncProvider.notifier).performInitialSync(),
            child: const Text('UNDUH SEKARANG', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ),
        if (syncState.isInitialSyncDone)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accent, foregroundColor: Colors.white),
            child: const Text('LANJUTKAN KE APLIKASI'),
          ),
      ],
    );
  }
}
