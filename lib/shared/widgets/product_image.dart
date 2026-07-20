import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ProductImage extends StatelessWidget {
  final String? imagePath;
  final double size;

  const ProductImage({
    super.key,
    this.imagePath,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: AppTheme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (imagePath == null || imagePath!.isEmpty) {
      return Icon(Icons.inventory_2_rounded, color: AppTheme.textMuted, size: size * 0.5);
    }

    final int cacheSize = (size * 2).toInt(); // 2x for retina quality but still limited

    if (imagePath!.startsWith('http')) {
      // Legacy network images
      return Image.network(
        imagePath!,
        fit: BoxFit.cover,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, color: AppTheme.danger, size: size * 0.5),
      );
    }

    // New local file images
    final file = File(imagePath!);
    if (!file.existsSync()) {
      return Icon(Icons.broken_image_rounded, color: AppTheme.danger, size: size * 0.5);
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, color: AppTheme.danger, size: size * 0.5),
    );
  }
}
