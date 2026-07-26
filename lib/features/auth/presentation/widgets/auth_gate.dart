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

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
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

        // --- IMPROVEMENT: Sync Trigger point ---
        // We trigger sync once settings are loaded.
        Future.microtask(() => ref.read(initialSyncProvider.notifier).performInitialSync());

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
}
