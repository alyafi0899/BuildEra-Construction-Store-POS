import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProductImage extends StatelessWidget {
  final String? imagePath;
  final double size;
  final double borderRadius;
  final IconData placeholderIcon;

  const ProductImage({
    super.key,
    this.imagePath,
    this.size = 40,
    this.borderRadius = 8,
    this.placeholderIcon = Icons.inventory_2_rounded,
  });

  @override
  Widget build(BuildContext context) {
    Widget? imageWidget;

    if (imagePath != null && imagePath!.isNotEmpty) {
      if (!kIsWeb && imagePath!.startsWith('/')) {
        // Local file path
        final file = File(imagePath!);
        if (file.existsSync()) {
          imageWidget = Image.file(file, fit: BoxFit.cover);
        }
      } 
      
      // Network URL or fallback
      imageWidget ??= Image.network(
        imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
            ),
          );
        },
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageWidget ?? _placeholder(),
    );
  }

  Widget _placeholder() {
    return Icon(placeholderIcon, color: AppTheme.accent, size: size * 0.5);
  }
}
