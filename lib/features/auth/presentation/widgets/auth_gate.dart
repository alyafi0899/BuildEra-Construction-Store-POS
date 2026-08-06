import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/sync/providers/initial_sync_provider.dart' as initial_sync_provider;
import '../../providers/auth_provider.dart';
import '../../models/auth_user.dart';
import '../pages/login_page.dart';
import '../pages/verify_email_page.dart';
import '../pages/setup_pin_page.dart';
import '../pages/enter_pin_page.dart';
import '../../providers/pin_unlock_provider.dart';
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
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (AuthUser? user) {
        if (user == null) {
          return const LoginPage();
        }
        
        // 1. Email Verification Check
        if (!user.isEmailVerified) {
          return const VerifyEmailPage();
        }

        // 2. Initial Data Sync Check (New Device)
        final syncState = ref.watch(initial_sync_provider.initialSyncProvider);
        if (!syncState.isInitialSyncDone) {
          return const _SyncingPage();
        }

        // 3. Store Settings & PIN Check
        final settings = ref.watch(settingsProvider);
        final hasPin = settings.securityPin != null && settings.securityPin!.isNotEmpty;
        
        // Wait for settings to load (especially important on new login)
        if (settings.businessName.isEmpty && settings.loginEmail == null) {
           return const SplashScreen(status: 'Memuat Pengaturan...');
        }

        // 4. Security PIN Setup (Only for BRAND NEW users who haven't set it up yet)
        // We check businessName.isEmpty as a proxy for 'has never finished onboarding'
        if (!hasPin && settings.businessName.isEmpty) {
          return const SetupPinPage();
        }

        // 5. Session Unlock (Only if PIN exists)
        if (hasPin) {
          final isUnlocked = ref.watch(pinUnlockProvider);
          if (!isUnlocked) {
            return const EnterPinPage();
          }
        }

        // 6. Access Granted
        return const MainShell();
      },
      loading: () => const SplashScreen(),
      error: (e, stack) => Scaffold(
        body: Center(child: Text('Terjadi kesalahan sistem: $e')),
      ),
    );
  }
}

class _SyncingPage extends ConsumerWidget {
  const _SyncingPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(initial_sync_provider.initialSyncProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
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
              const Icon(Icons.cloud_download_rounded, size: 64, color: AppTheme.accent),
              const SizedBox(height: 24),
              const Text('Sinkronisasi Data', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Perangkat baru terdeteksi. Silakan unduh data Anda dari cloud untuk melanjutkan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 40),
              if (syncState.isSyncing) ...[
                const CircularProgressIndicator(color: AppTheme.accent),
                const SizedBox(height: 24),
                const Text('Mengunduh data...', style: TextStyle(color: AppTheme.accent, fontSize: 14)),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => ref.read(initial_sync_provider.initialSyncProvider.notifier).performInitialSync(),
                    child: const Text('UNDUH DATA SEKARANG'),
                  ),
                ),
                if (syncState.error != null) ...[
                  const SizedBox(height: 16),
                  Text('Error: ${syncState.error}', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.danger, fontSize: 12)),
                ],
              ],
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => ref.read(authRepositoryProvider).logout(),
                child: const Text('Batal & Keluar', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

