import 'dart:io';
import 'package:flutter/material.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: colorScheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (imagePath == null || imagePath!.isEmpty) {
      return Icon(Icons.inventory_2_rounded, color: colorScheme.onSurface.withValues(alpha: 0.4), size: size * 0.5);
    }

    if (imagePath!.startsWith('http')) {
      return Image.network(
        imagePath!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, color: colorScheme.error, size: size * 0.5),
      );
    }

    final file = File(imagePath!);
    if (!file.existsSync()) {
      return Icon(Icons.broken_image_rounded, color: colorScheme.error, size: size * 0.5);
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Icon(Icons.broken_image_rounded, color: colorScheme.error, size: size * 0.5),
    );
  }
}
