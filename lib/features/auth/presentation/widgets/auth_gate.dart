import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../pages/login_page.dart';
import '../pages/verify_email_page.dart';
import '../../../../main.dart'; 
import '../../../../shared/widgets/splash_screen.dart';

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

        // Removed the settings.loginEmail check that was causing hangs.
        // For the Manager Android version, we go straight to MainShell.
        return const MainShell();
      },
      loading: () => const SplashScreen(status: 'Otentikasi...'),
      error: (e, stack) => Scaffold(
        backgroundColor: const Color(0xFF0F1117),
        body: Center(child: Text('Kesalahan Sistem: $e', style: const TextStyle(color: Colors.white))),
      ),
    );
  }
}
