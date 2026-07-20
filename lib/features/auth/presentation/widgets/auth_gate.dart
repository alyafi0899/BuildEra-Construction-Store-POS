import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../pages/login_page.dart';
import '../pages/verify_email_page.dart';
import '../pages/setup_pin_page.dart';
import '../../../../main.dart'; // To get MainShell or whatever home is
import '../../../../shared/widgets/splash_screen.dart';
import '../../../settings/providers/settings_provider.dart';

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
        // but settingsProvider uses watch(authStateProvider) and then _loadSettings.
        // If the user has a PIN, securityPin will be non-null after load.
        // We use a simple check: if loginEmail is null, it might be still loading
        if (settings.loginEmail == null) {
           return const SplashScreen(status: 'Memuat Pengaturan...');
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
}
