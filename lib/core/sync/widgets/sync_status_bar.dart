import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../providers/sync_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/initial_sync_provider.dart';

class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final syncState = ref.watch(syncProvider);

    Color color;
    IconData icon;
    String label;
    String? subLabel;

    if (!isOnline) {
      color = AppTheme.textMuted;
      icon = Icons.cloud_off_rounded;
      label = 'Offline';
      subLabel = 'Bekerja secara lokal';
    } else if (syncState.lastError != null) {
      color = AppTheme.danger;
      icon = Icons.sync_problem_rounded;
      label = 'Error Sinkronisasi';
      subLabel = 'Akan dicoba lagi otomatis';
    } else if (syncState.pendingCount > 0) {
      color = AppTheme.warning;
      icon = Icons.sync_rounded;
      label = 'Sedang Sinkronisasi';
      subLabel = '${syncState.pendingCount} data tersisa';
    } else {
      color = AppTheme.success;
      icon = Icons.cloud_done_rounded;
      label = 'Tersinkronisasi';
      if (syncState.lastSyncAt != null) {
        subLabel = 'Terakhir:${Formatters.dateTime(syncState.lastSyncAt!)}';
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulseIcon(icon: icon, color: color, pulsing: syncState.isSyncing),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    if (subLabel != null)
                      Text(
                        subLabel,
                        style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ManualSyncButton(),
      ],
    );
  }
}

class _ManualSyncButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(initialSyncProvider);
    final isOnline = ref.watch(isOnlineProvider);

    return InkWell(
      onTap: (!isOnline || syncState.isSyncing) 
          ? null 
          : () => ref.read(initialSyncProvider.notifier).triggerManualSync(),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (syncState.isSyncing)
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
              )
            else
              const Icon(Icons.download_for_offline_rounded, size: 16, color: AppTheme.accent),
            const SizedBox(width: 8),
            Text(
              syncState.isSyncing ? 'Mengunduh...' : 'Unduh Data Cloud',
              style: const TextStyle(color: AppTheme.accent, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}


class _PulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool pulsing;

  const _PulseIcon({required this.icon, required this.color, required this.pulsing});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    if (widget.pulsing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulsing && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.pulsing) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: widget.pulsing ? _controller : const AlwaysStoppedAnimation(0),
      child: Icon(widget.icon, color: widget.color, size: 20),
    );
  }
}
