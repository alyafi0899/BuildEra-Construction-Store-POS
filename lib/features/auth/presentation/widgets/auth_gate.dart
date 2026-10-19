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
import '../../../../core/providers/feature_tour_provider.dart';
import '../../../../core/localization/app_language.dart';
import '../../../settings/providers/app_settings_provider.dart';

class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _dialogShown = false;

  @override
  Widget build(BuildContext context) {
    final tourState = ref.watch(featureTourProvider);
    if (!tourState.isLanguageSelected) {
      return const Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(child: _InitialLanguageDialog()),
      );
    }

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
        
        if ((settings.securityPin?.length ?? 0) < 4) {
           return const SetupPinPage();
        }

        return const MainShell();
      },
      loading: () => const SplashScreen(status: 'Menghubungkan ke Server...'),
      error: (e, stack) => Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_off_rounded, color: AppTheme.warning, size: 40),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Koneksi Internet Terputus',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Aplikasi membutuhkan koneksi internet di awal saat dibuka untuk verifikasi keamanan akun.\nPastikan paket data atau Wi-Fi Anda aktif.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => ref.refresh(authStateProvider),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('HUBUNGKAN ULANG'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => ref.read(authRepositoryProvider).logout(),
                      child: const Text('KEMBALI KE HALAMAN LOGIN', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),
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
        if (!syncState.isSyncing && !syncState.isInitialSyncDone) ...[
          if (syncState.error != null)
            TextButton(
              onPressed: () async {
                await ref.read(initialSyncProvider.notifier).markAsDone();
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('LEWATI & LANJUTKAN', style: TextStyle(color: AppTheme.textMuted)),
            ),
          TextButton(
            onPressed: () => ref.read(initialSyncProvider.notifier).performInitialSync(),
            child: const Text('UNDUH SEKARANG', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold)),
          ),
        ],
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

class _InitialLanguageDialog extends ConsumerWidget {
  const _InitialLanguageDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language_rounded, size: 48, color: AppTheme.accent),
            const SizedBox(height: 16),
            const Text(
              'Pilih Bahasa / Select Language',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Silakan pilih bahasa aplikasi Anda\nPlease choose your preferred language',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ...AppLanguage.values.map((lang) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: Text(lang.flag, style: const TextStyle(fontSize: 24)),
                  title: Text(lang.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppTheme.border),
                  ),
                  tileColor: AppTheme.surfaceAlt,
                  onTap: () {
                    ref.read(appSettingsProvider.notifier).setLanguage(lang);
                    ref.read(featureTourProvider.notifier).markLanguageSelected();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
