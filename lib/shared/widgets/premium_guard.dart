import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/subscription/providers/subscription_provider.dart';
import '../../features/subscription/presentation/pages/subscription_page.dart';
import '../../core/theme/app_theme.dart';

class PremiumGuard extends ConsumerWidget {
  final Widget child;
  final String featureName;

  const PremiumGuard({
    super.key,
    required this.child,
    this.featureName = 'Fitur ini',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final subAsync = ref.watch(subscriptionStateProvider);

    return subAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error checking subscription: $err')),
      data: (sub) {
        if (isPremium) {
          return child;
        }

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: AppTheme.bg.withValues(alpha: 0.8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_person_rounded,
                          size: 64,
                          color: AppTheme.accent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '$featureName Khusus Premium',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Tingkatkan akun Anda ke paket Full Features untuk membuka fitur ini dan kelola toko Anda dengan lebih maksimal.',
                        style: TextStyle(
                          color: AppTheme.textMuted,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text(
                          'LIHAT PAKET PREMIUM',
                          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
