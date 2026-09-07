import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../providers/subscription_provider.dart';

class SubscriptionGuard extends ConsumerWidget {
  final Widget child;
  final String featureName;
  final bool showLockIcon;

  const SubscriptionGuard({
    super.key,
    required this.child,
    required this.featureName,
    this.showLockIcon = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    if (isPremium) return child;

    return Stack(
      children: [
        // Greyed out child
        Opacity(
          opacity: 0.3,
          child: AbsorbPointer(child: child),
        ),
        
        // Lock Overlay
        if (showLockIcon)
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        featureName,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
