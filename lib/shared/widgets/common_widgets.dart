import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';

// ── PageHeader ───────────────────────────────────────────────────────────

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget>? actions;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.accent, size: 24),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(width: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions!,
            ),
          ],
        ],
      ),
    );
  }
}

// ── AppCard ───────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

// ── StatCard ──────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;
  final String? subtitle;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppTheme.accent;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 12),
          Text(value,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  )),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

// ── SectionHeader ─────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? icon;
  final Color? color;

  const SectionHeader(
      {super.key, required this.title, this.trailing, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (icon != null) ...[
        Icon(icon, color: color ?? AppTheme.accent, size: 18),
        const SizedBox(width: 8),
      ],
      Text(title,
          style:
              Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
      const Spacer(),
      if (trailing != null) trailing!,
    ]);
  }
}

// ── StatusChip ────────────────────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── SearchField ───────────────────────────────────────────────────────────

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const AppSearchField({
    super.key,
    required this.controller,
    this.focusNode,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12, right: 4),
                  child:
                      Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                ),
                if (value.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, size: 20),
                    onPressed: () {
                      controller.clear();
                      if (onClear != null) onClear!();
                      if (onChanged != null) onChanged!('');
                    },
                    color: AppTheme.accent,
                    tooltip: 'Hapus Pencarian',
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: AppTheme.textMuted),
          const SizedBox(height: 16),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppTheme.textSecondary)),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────

class AppDivider extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  const AppDivider({super.key, this.margin});

  @override
  Widget build(BuildContext context) {
    return Divider(
      color: AppTheme.border,
      height: 1,
      thickness: 1,
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.accent),
    );
  }
}

// ── Confirm Dialog ────────────────────────────────────────────────────────

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Hapus',
  Color confirmColor = AppTheme.danger,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

// ── Logout Dialog ──────────────────────────────────────────────────────────

Future<bool> showLogoutDialog(BuildContext context) async {
  return await showConfirmDialog(
    context,
    title: 'Konfirmasi Keluar',
    content:
        'Apakah Anda yakin ingin keluar dari akun Anda? Anda perlu masuk kembali untuk mengakses data.',
    confirmLabel: 'KELUAR',
    confirmColor: AppTheme.danger,
  );
}

// ── Snack helpers ─────────────────────────────────────────────────────────

void showSuccess(BuildContext context, String msg) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars(); // Clear existing to prevent "stacking" lag
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_outline, color: AppTheme.success, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg)),
    ]),
    duration: const Duration(
        milliseconds: 1500), // Reduced to 1.5s for faster scanning
    behavior: SnackBarBehavior.floating,
    width: 320,
  ));
}

void showError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline, color: AppTheme.danger, size: 18),
      const SizedBox(width: 8),
      Text(msg),
    ]),
    duration: const Duration(seconds: 3),
  ));
}

// ── Qty Scroll Wrapper ────────────────────────────────────────────────────

class ScrollableQtyField extends StatefulWidget {
  final Widget child;
  final TextEditingController controller;
  final Function(double)? onChanged;
  final double step;
  final double minValue;
  final bool isCurrency;

  const ScrollableQtyField({
    super.key,
    required this.child,
    required this.controller,
    this.onChanged,
    this.step = 1.0,
    this.minValue = 0,
    this.isCurrency = true,
  });

  @override
  State<ScrollableQtyField> createState() => _ScrollableQtyFieldState();
}

class _ScrollableQtyFieldState extends State<ScrollableQtyField> {
  // Use a local numeric state as the source of truth to avoid parsing loops
  late double _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = _parseValue(widget.controller.text);
  }

  @override
  void didUpdateWidget(covariant ScrollableQtyField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync internal value if controller text changed externally (e.g. new product added)
    if (widget.controller.text != oldWidget.controller.text) {
      _currentValue = _parseValue(widget.controller.text);
    }
  }

  double _parseValue(String text) {
    final clean = text.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0.0;
  }

  void _updateValue(double delta) {
    // Re-sync with controller in case user typed something manually
    _currentValue = _parseValue(widget.controller.text);

    if (delta < 0) {
      _currentValue += widget.step;
    } else {
      _currentValue -= widget.step;
    }

    if (_currentValue < widget.minValue) _currentValue = widget.minValue;

    // Format for display
    String formatted;
    if (widget.isCurrency) {
      formatted = NumberFormat.decimalPattern('id_ID').format(_currentValue.toInt());
    } else {
      // Qty: precise decimal handling
      formatted = _currentValue % 1 == 0 
          ? _currentValue.toInt().toString() 
          : _currentValue.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    }

    // Update UI atomicly
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );

    if (widget.onChanged != null) widget.onChanged!(_currentValue);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          if (pointerSignal.scrollDelta.dy == 0) return;
          _updateValue(pointerSignal.scrollDelta.dy);
        }
      },
      child: widget.child,
    );
  }
}
