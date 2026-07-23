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
    final textTheme = Theme.of(context).textTheme;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, isMobile ? 48 : 24, 20, isMobile ? 12 : 20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null && !isMobile) ...[
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
                      style: isMobile 
                        ? textTheme.headlineMedium?.copyWith(fontSize: 20, fontWeight: FontWeight.bold)
                        : textTheme.headlineLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && !isMobile) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (!isMobile && actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!.expand((w) => [w, const SizedBox(width: 12)]).toList()
                    ..removeLast(),
                ),
              ],
            ],
          ),
          if (isMobile && actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: actions!.expand((w) => [w, const SizedBox(width: 8)]).toList()
                  ..removeLast(),
              ),
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
  final double? elevation;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin,
      child: Card(
        color: color ?? colorScheme.surface,
        elevation: elevation ?? 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
=======
    return Card(
      color: color,
      elevation: elevation ?? 2,
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child:   child,
>>>>>>> parent of bd29cdf (fixing bug)
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
    final color = accentColor ?? Theme.of(context).colorScheme.primary;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
          ]),
          const SizedBox(height: 16),
          Text(value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  )),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      child: Row(children: [
        if (icon != null) ...[
          Icon(icon, color: color ?? colorScheme.primary, size: 20),
          const SizedBox(width: 10),
        ],
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        )),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ── SearchField ───────────────────────────────────────────────────────────

class AppSearchField extends StatefulWidget {
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
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SearchBar(
      controller: widget.controller,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      hintText: widget.hintText,
      elevation: WidgetStateProperty.all(0),
      backgroundColor: WidgetStateProperty.all(colorScheme.surfaceContainer),
      padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16)),
      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      leading: const Icon(Icons.search_rounded),
      trailing: widget.controller.text.isNotEmpty 
        ? [IconButton(onPressed: () {
            widget.controller.clear();
            if (widget.onClear != null) widget.onClear!();
          }, icon: const Icon(Icons.close_rounded))] 
        : null,
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 32), action!],
          ],
        ),
      ),
    );
  }
}

// ── Loading ───────────────────────────────────────────────────────────────

class AppLoading extends StatelessWidget {
  const AppLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

// ── Confirm Dialog ────────────────────────────────────────────────────────

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmLabel = 'Konfirmasi',
  Color? confirmColor,
}) async {
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
              style:     ElevatedButton.styleFrom(
                backgroundColor: confirmColor ?? Theme.of(context).colorScheme.primary,
                minimumSize: const Size(100, 44),
              ),
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
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(msg)),
    ]),
    duration: const Duration(milliseconds: 2000),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
  ));
}

void showError(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(msg)),
    ]),
    duration: const Duration(seconds: 4),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(16),
  ));
}
