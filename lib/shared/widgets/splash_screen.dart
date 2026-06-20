import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 40),
            // App Name
            Text(
              'BuildEra',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                letterSpacing: 6,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Material and Construction POS',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bangun. Kelola. Kembangkan.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 60),
            // Loading indicator
            const SizedBox(
              width: 200,
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
