import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/initial_sync_provider.dart';
import '../../theme/app_theme.dart';

class InitialSyncScreen extends ConsumerWidget {
  const InitialSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(initialSyncProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sync_rounded, size: 48, color: AppTheme.accent),
              const SizedBox(height: 24),
              Text(
                'Menyiapkan Data Anda',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Mohon tunggu sebentar selagi kami mengunduh data Anda dari server. Ini hanya dilakukan sekali saat pertama kali masuk.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: syncState.progress,
                  backgroundColor: AppTheme.surfaceAlt,
                  color: AppTheme.accent,
                  minHeight: 10,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    syncState.currentStep,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  ),
                  Text(
                    '${(syncState.progress * 100).toInt()}%',
                    style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (syncState.error != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Terjadi Kesalahan Sinkronisasi',
                        style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        syncState.error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.danger, fontSize: 11),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.read(initialSyncProvider.notifier).performInitialSync(),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
