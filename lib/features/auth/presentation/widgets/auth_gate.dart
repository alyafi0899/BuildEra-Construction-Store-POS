import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../pages/login_page.dart';
import '../pages/verify_email_page.dart';
import '../pages/setup_pin_page.dart';
import '../../../../main.dart'; // To get MainShell or whatever home is
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

    // Listen to sync state to show dialog
    ref.listen(initialSyncProvider, (prev, next) {
      // Only prompt if sync is not done AND not already syncing AND not yet shown in this session
      if (next.isInitialSyncDone == false && !_dialogShown && !next.isSyncing && next.error == null) {
         _showSyncPrompt();
      }
    });

    return authState.when(
      data: (user) {
        if (user == null) {
          _dialogShown = false;
          return const LoginPage();
        }
        
        if (!user.isEmailVerified) {
          return const VerifyEmailPage();
        }

        // Check for PIN enforcement
        final settings = ref.watch(settingsProvider);
        
        // If settings are still loading or initial, we might need to wait 
        if (settings.loginEmail == null) {
           return Scaffold(
             backgroundColor: const Color(0xFF0F1117),
             body: Center(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const SizedBox(
                     width: 40,
                     height: 40,
                     child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.accent),
                   ),
                   const SizedBox(height: 16),
                   Text('Memuat Pengaturan...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                 ],
               ),
             ),
           );
        }

        if (settings.securityPin == null) {
          return const SetupPinPage();
        }

        return const MainShell();
      },
      loading: () => const SplashScreen(),
      error: (e, stack) => Scaffold(
        body: Center(child: Text('Terjadi kesalahan sistem: $e')),
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
            const CircularProgressIndicator(color: AppTheme.accent),
            const SizedBox(height: 16),
            const Text('Mengunduh data...', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
          ],
          if (syncState.error != null) ...[
            const SizedBox(height: 16),
            Text('Error: ${syncState.error}', style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
          ],
        ],
      ),
      actions: [
        if (!syncState.isSyncing && !syncState.isInitialSyncDone)
          TextButton(
            onPressed: () => ref.read(initialSyncProvider.notifier).performInitialSync(),
            child: const Text('Unduh Sekarang', style: TextStyle(color: AppTheme.accent)),
          ),
        if (syncState.isInitialSyncDone)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Lanjutkan ke Aplikasi'),
          ),
      ],
    );
  }
}

