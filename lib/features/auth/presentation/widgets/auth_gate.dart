import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../pages/login_page.dart';
import '../pages/verify_email_page.dart';
import '../../../../main.dart'; // To get MainShell or whatever home is
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

        return const MainShell();
      },
      loading: () => const SplashScreen(),
      error: (e, stack) => Scaffold(
        body: Center(child: Text('Terjadi kesalahan sistem: $e')),
      ),
    );
  }
}
