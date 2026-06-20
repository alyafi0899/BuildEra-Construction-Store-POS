import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../models/product.dart';
import 'product_image.dart';

class ProductDetailDialog extends StatelessWidget {
  final Product product;
  const ProductDetailDialog({super.key, required this.product});

  static Future<void> show(BuildContext context, Product product) {
    return showDialog(
      context: context,
      builder: (_) => ProductDetailDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Large Image
                GestureDetector(
                  onTap: () => _showFullImage(context),
                  child: ProductImage(imagePath: product.imagePath, size: 200),
                ),
                const SizedBox(width: 32),
                
                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.category.toUpperCase(), 
                        style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Text(product.name, 
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                      if (product.barcode != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.qr_code_2_rounded, size: 16, color: AppTheme.textMuted),
                            const SizedBox(width: 8),
                            Text(product.barcode!, style: const TextStyle(color: AppTheme.textMuted, fontSize: 14)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      Text(
                        Formatters.currency(product.basePrice),
                        style: const TextStyle(color: AppTheme.accent, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      Text('Stok Tersedia: ${Formatters.decimal(product.stock)} ${product.baseUnit}',
                        style: TextStyle(
                          color: product.isLowStock ? AppTheme.warning : AppTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        )),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 48),
            
            // Description
            const Text('DESKRIPSI PRODUK', 
              style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 12),
            Text(
              product.description ?? 'Tidak ada deskripsi untuk produk ini.',
              style: const TextStyle(height: 1.6, fontSize: 14, color: AppTheme.textPrimary),
            ),
            
            if (product.units.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text('SATUAN LAINNYA', 
                style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: product.units.map((u) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.unitName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(Formatters.currency(u.sellPrice), style: const TextStyle(color: AppTheme.accent, fontSize: 13)),
                    ],
                  ),
                )).toList(),
              ),
            ],
            
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: AppTheme.surfaceAlt,
                  foregroundColor: AppTheme.textPrimary,
                ),
                child: const Text('TUTUP'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context) {
    if (product.imagePath == null) return;
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black.withValues(alpha: 0.8),
                child: InteractiveViewer(
                  maxScale: 4,
                  child: _buildImageSource(),
                ),
              ),
            ),
            PositionError(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSource() {
    if (product.imagePath!.startsWith('http')) {
      return Image.network(product.imagePath!, fit: BoxFit.contain);
    }
    return Image.file(File(product.imagePath!), fit: BoxFit.contain);
  }
}

class PositionError extends StatelessWidget {
  final Widget child;
  const PositionError({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Positioned(top: 20, right: 20, child: child);
  }
}
