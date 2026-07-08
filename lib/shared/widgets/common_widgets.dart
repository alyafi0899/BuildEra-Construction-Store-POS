import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outline)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary, size: 24),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: actions!.expand((w) => [w, const SizedBox(width: 12)]).toList()
                ..removeLast(),
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
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child:   child,
        ),
      ),
    );
  }
}

// ── StatCard ──────────────────────────────────────────────────────────────

class StatCard extends StatelessWidget {
  final String  label;
  final String  value;
  final IconData icon;
  final Color?  accentColor;
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
    final colorScheme = Theme.of(context).colorScheme;
    final color = accentColor ?? colorScheme.primary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding:     const EdgeInsets.all(8),
              decoration:  BoxDecoration(
                color:        color.withValues(alpha: 0.15),
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
                    color:      colorScheme.onSurface,
                    fontSize:   22,
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
  final String   title;
  final Widget?  trailing;
  final IconData? icon;
  final Color?   color;

  const SectionHeader({super.key, required this.title, this.trailing, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final finalColor = color ?? colorScheme.primary;
    return Row(children: [
      if (icon != null) ...[
        Icon(icon, color: finalColor, size: 18),
        const SizedBox(width: 8),
      ],
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: finalColor)),
      const Spacer(),
      if (trailing != null) trailing!,
    ]);
  }
}

// ── StatusChip ────────────────────────────────────────────────────────────

class StatusChip extends StatelessWidget {
  final String label;
  final Color  color;
  const StatusChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border:       Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

// ── SearchField ───────────────────────────────────────────────────────────

class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode; // New
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const AppSearchField({
    super.key,
    required this.controller,
    this.focusNode, // New
    required this.hintText,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: controller,
      focusNode:  focusNode, // Use FocusNode
      onChanged:  onChanged,
      style: TextStyle(color: colorScheme.onSurface),
      decoration: InputDecoration(
        hintText:    hintText,
        prefixIcon:  Icon(Icons.search, color: colorScheme.onSurface.withValues(alpha: 0.5), size: 20),
        suffixIcon:  controller.text.isNotEmpty
            ? IconButton(
                icon:    const Icon(Icons.clear, size: 18),
                onPressed: onClear,
                color:   colorScheme.onSurface.withValues(alpha: 0.5),
              )
            : null,
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  subtitle;
  final Widget?  action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.7))),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
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
      color:  Theme.of(context).colorScheme.outline,
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
    return Center(
      child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
    );
  }
}

// ── Confirm Dialog ────────────────────────────────────────────────────────

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Hapus',
  Color? confirmColor,
}) async {
  final color = confirmColor ?? Theme.of(context).colorScheme.error;
  return await showDialog<bool>(
        context:  context,
        builder:  (_) => AlertDialog(
          title:   Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style:     ElevatedButton.styleFrom(backgroundColor: color),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

// ── Snack helpers ─────────────────────────────────────────────────────────

void showSuccess(BuildContext context, String msg) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: colorScheme.primaryContainer,
    content: Row(children: [
      Icon(Icons.check_circle_outline, color: colorScheme.onPrimaryContainer, size: 18),
      const SizedBox(width: 8),
      Text(msg, style: TextStyle(color: colorScheme.onPrimaryContainer)),
    ]),
    duration: const Duration(seconds: 2),
  ));
}

void showError(BuildContext context, String msg) {
  final colorScheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    backgroundColor: colorScheme.errorContainer,
    content: Row(children: [
      Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 18),
      const SizedBox(width: 8),
      Text(msg, style: TextStyle(color: colorScheme.onErrorContainer)),
    ]),
    duration: const Duration(seconds: 3),
  ));
}
