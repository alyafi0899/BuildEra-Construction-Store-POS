import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../models/product.dart';
import 'product_image.dart';
import '../../features/payment/providers/transaction_provider.dart';
import '../../features/products/models/product_financials.dart';
import 'common_widgets.dart';

class ProductDetailDialog extends ConsumerWidget {
  final Product product;
  const ProductDetailDialog({super.key, required this.product});

  static Future<void> show(BuildContext context, Product product) {
    return showDialog(
      context: context,
      builder: (_) => ProductDetailDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(salesSummaryProvider);
    final f = product.financials;
    final unitProfit = product.basePrice - product.costPrice;
    final margin = product.costPrice > 0 ? (unitProfit / product.costPrice) * 100 : 0.0;

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800, // Increased width for better breakdown display
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
                  child: ProductImage(imagePath: product.imagePath, size: 220),
                ),
                const SizedBox(width: 32),
                
                // Main Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(product.category.toUpperCase(), 
                            style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                          const Spacer(),
                          if (f.supplierName != null)
                            _miniBadge(Icons.business_rounded, f.supplierName!),
                        ],
                      ),
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
                      Row(
                        children: [
                          _statItem(context, 'Stok Tersedia', '${Formatters.decimal(product.stock)} ${product.baseUnit}', 
                            color: product.isLowStock ? AppTheme.warning : AppTheme.success),
                          const SizedBox(width: 32),
                          _statItem(context, 'Harga Jual', Formatters.currency(product.basePrice), color: AppTheme.accent),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 48),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cost & Pricing ──────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SubLabel('COST BREAKDOWN'),
                      const SizedBox(height: 16),
                      _detailRow('Harga Beli Supplier', Formatters.currency(f.supplierPrice)),
                      _detailRow('Ongkos Kirim', Formatters.currency(f.supplierShippingCost)),
                      const Divider(height: 24, thickness: 0.5),
                      _detailRow('Total Modal (Unit)', Formatters.currency(product.costPrice), isBold: true),
                      
                      const SizedBox(height: 32),
                      const _SubLabel('PRICING & MARGIN'),
                      const SizedBox(height: 16),
                      _detailRow('Harga Jual Dasar', Formatters.currency(product.basePrice)),
                      _detailRow('Profit Bersih / Unit', Formatters.currency(unitProfit), color: AppTheme.success),
                      _detailRow('Profit Margin', '${margin.toStringAsFixed(1)}%', color: AppTheme.info),
                    ],
                  ),
                ),
                const SizedBox(width: 48),
                
                // ── Payments & Sales ────────────────────────────────
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SubLabel('PAYMENT STATUS'),
                      const SizedBox(height: 16),
                      _paymentStatusItem('Barang (Supplier)', f.supplierPaymentStatus),
                      const SizedBox(height: 12),
                      _paymentStatusItem('Ongkir (Ekspedisi)', f.shippingPaymentStatus),

                      const SizedBox(height: 32),
                      const _SubLabel('SALES STATISTICS'),
                      const SizedBox(height: 16),
                      summaryAsync.when(
                        data: (s) {
                          final stats = s.topProducts.firstWhere((tp) => tp.name == product.name, 
                            orElse: () => TopProduct(name: product.name, unit: product.baseUnit, revenue: 0, profit: 0, qty: 0, costPrice: 0, soldPrice: 0));
                          
                          return Column(
                            children: [
                              _detailRow('Unit Terjual', '${Formatters.decimal(stats.qty)} ${product.baseUnit}'),
                              _detailRow('Total Omzet', Formatters.currency(stats.revenue)),
                              _detailRow('Total Net Profit', Formatters.currency(stats.profit), color: AppTheme.success, isBold: true),
                            ],
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const Text('Gagal memuat statistik'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (product.units.isNotEmpty) ...[
              const SizedBox(height: 32),
              const _SubLabel('SATUAN JUAL LAINNYA'),
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
                      Text('Konv: ${u.conversionRate} ${product.baseUnit}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
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

  Widget _statItem(BuildContext context, String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color ?? AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _detailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(
            color: color ?? AppTheme.textPrimary, 
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            fontSize: isBold ? 14 : 13,
          )),
        ],
      ),
    );
  }

  Widget _paymentStatusItem(String label, PaymentStatus status) {
    final color = status == PaymentStatus.paid ? AppTheme.success 
                : status == PaymentStatus.unpaid ? AppTheme.warning 
                : AppTheme.textMuted;
    
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status == PaymentStatus.paid ? Icons.check_circle_rounded : Icons.info_rounded, size: 12, color: color),
              const SizedBox(width: 6),
              Text(status.label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _miniBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
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
            Positioned(
              top: 20, right: 20,
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

class _SubLabel extends StatelessWidget {
  final String text;
  const _SubLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.2));
  }
}
