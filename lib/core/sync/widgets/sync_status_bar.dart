import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import '../providers/sync_provider.dart';
import '../providers/connectivity_provider.dart';

class SyncStatusBar extends ConsumerWidget {
  const SyncStatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final syncState = ref.watch(syncProvider);
    final colorScheme = Theme.of(context).colorScheme;

    Color color;
    IconData icon;
    String label;
    String? subLabel;

    if (!isOnline) {
      color = colorScheme.onSurface.withValues(alpha: 0.5);
      icon = Icons.cloud_off_rounded;
      label = 'Offline';
      subLabel = 'Bekerja secara lokal';
    } else if (syncState.lastError != null) {
      color = colorScheme.error;
      icon = Icons.sync_problem_rounded;
      label = 'Error Sinkronisasi';
      subLabel = 'Akan dicoba lagi otomatis';
    } else if (syncState.pendingCount > 0) {
      color = const Color(0xFFF39C12); // Warning color
      icon = Icons.sync_rounded;
      label = 'Sedang Sinkronisasi';
      subLabel = '${syncState.pendingCount} data tersisa';
    } else {
      color = const Color(0xFF2ECC71); // Success color
      icon = Icons.cloud_done_rounded;
      label = 'Tersinkronisasi';
      if (syncState.lastSyncAt != null) {
        subLabel = 'Terakhir: ${Formatters.dateTime(syncState.lastSyncAt!)}';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
        ],
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
