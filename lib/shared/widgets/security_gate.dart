import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../features/settings/providers/settings_provider.dart';

/// A provider that tracks the global PIN unlock state.
/// This allows once-per-session (or until manual lock) unlocking.
final pinUnlockProvider = NotifierProvider<PinUnlockNotifier, bool>(PinUnlockNotifier.new);

class PinUnlockNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void unlock() => state = true;
  void lock() => state = false;
}

/// Helper to require PIN for a specific action.
void requirePin(BuildContext context, WidgetRef ref, VoidCallback onSuccess) {
  final isUnlocked = ref.read(pinUnlockProvider);
  final settings = ref.read(settingsProvider);

  if (isUnlocked || settings.securityPin == null) {
    onSuccess();
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ActionPinDialog(onSuccess: onSuccess),
  );
}

class _ActionPinDialog extends ConsumerWidget {
  final VoidCallback onSuccess;
  const _ActionPinDialog({required this.onSuccess});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: _PinPromptOverlay(
        isDialog: true,
        onSuccess: () {
          Navigator.pop(context);
          onSuccess();
        },
      ),
    );
  }
}

class PinGate extends ConsumerWidget {
  final Widget child;
  const PinGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnlocked = ref.watch(pinUnlockProvider);
    final settings = ref.watch(settingsProvider);

    if (isUnlocked || settings.securityPin == null) {
      return child;
    }

    return _PinPromptOverlay(
      onSuccess: () => ref.read(pinUnlockProvider.notifier).unlock(),
    );
  }
}

class BlurGate extends ConsumerWidget {
  final Widget child;
  const BlurGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnlocked = ref.watch(pinUnlockProvider);
    final settings = ref.watch(settingsProvider);

    if (isUnlocked || settings.securityPin == null) {
      return child;
    }

    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Container(
            color: AppTheme.surface.withValues(alpha: 0.98), // Solid cover is 100x faster than blur
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_rounded, color: AppTheme.accent, size: 14),
                    const SizedBox(height: 2),
                    TextButton(
                      onPressed: () => _showPinDialog(context, ref),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Unlock', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
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

  void _showPinDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: _PinPromptOverlay(
          isDialog: true,
          onSuccess: () {
            ref.read(pinUnlockProvider.notifier).unlock();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _PinPromptOverlay extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  final bool isDialog;
  const _PinPromptOverlay({required this.onSuccess, this.isDialog = false});

  @override
  ConsumerState<_PinPromptOverlay> createState() => _PinPromptOverlayState();
}

class _PinPromptOverlayState extends ConsumerState<_PinPromptOverlay> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  String _error = '';

  @override
  void initState() {
    super.initState();
    // Ensure focus is requested after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged(String value, int index) {
    final settings = ref.read(settingsProvider);
    final pinLength = settings.securityPin?.length ?? 4;

    if (value.length == 1) {
      if (index < pinLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _verify();
      }
    }
  }

  void _verify() {
    final enteredPin = _controllers.map((c) => c.text).join();
    final correctPin = ref.read(settingsProvider).securityPin;

    if (enteredPin == correctPin) {
      widget.onSuccess();
    } else {
      setState(() {
        _error = 'PIN Salah';
        for (var c in _controllers) {
          c.clear();
        }
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final pinLength = settings.securityPin?.length ?? 4;

    return Container(
      width: widget.isDialog ? 360 : double.infinity,
      height: widget.isDialog ? null : double.infinity,
      color: widget.isDialog ? AppTheme.surface : AppTheme.bg,
      padding: const EdgeInsets.all(40),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 64, color: AppTheme.accent),
              const SizedBox(height: 24),
              Text(
                'Akses Terbatas',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan PIN Keamanan untuk melihat data sensitif',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pinLength, (index) {
                  return Container(
                    width: 45,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      autofocus: index == 0,
                      obscureText: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(1),
                      ],
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.surfaceAlt,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.accent, width: 2),
                        ),
                      ),
                      onChanged: (v) => _onChanged(v, index),
                      onSubmitted: (_) => _verify(),
                    ),
                  );
                }),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_error, style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 40),
              if (widget.isDialog)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
