import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../models/product.dart';
import 'product_image.dart';
import '../../features/payment/providers/transaction_provider.dart';
import '../../features/products/models/product_financials.dart';

class ProductDetailDialog extends ConsumerWidget {
  final Product product;
  const ProductDetailDialog({super.key, required this.product});

  static Future<void> show(BuildContext context, Product product) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (_) => ProductDetailDialog(product: product),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(salesSummaryProvider);
    final f = product.financials;
    final unitProfit = product.basePrice - product.costPrice;
    final margin = product.costPrice > 0 ? (unitProfit / product.costPrice) * 100 : 0.0;

    return Column(
      children: [
        Container(
          height: 5, width: 40,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(5)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text('Detail Produk', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Product Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductImage(imagePath: product.imagePath, size: 100),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        Text(product.category, style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                        if (product.barcode != null)
                          Text('Barcode: ${product.barcode}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Inventory Stats
              Row(
                children: [
                  Expanded(child: _statCard('Stok Saat Ini', '${Formatters.decimal(product.stock)} ${product.baseUnit}', 
                    product.isLowStock ? AppTheme.danger : AppTheme.success)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard('Harga Jual', Formatters.currency(product.basePrice), AppTheme.primary)),
                ],
              ),
              
              const SizedBox(height: 24),
              const _SectionTitle('Rincian Modal & Margin'),
              AppCard(
                child: Column(
                  children: [
                    _infoRow('Harga Beli', Formatters.currency(f.supplierPrice)),
                    _infoRow('Ongkos Kirim', Formatters.currency(f.supplierShippingCost)),
                    const Divider(height: 24),
                    _infoRow('Total Modal / Unit', Formatters.currency(product.costPrice), isBold: true),
                    _infoRow('Profit / Unit', Formatters.currency(unitProfit), color: AppTheme.success),
                    _infoRow('Margin Profit', '${margin.toStringAsFixed(1)}%', color: AppTheme.info),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const _SectionTitle('Statistik Penjualan'),
              summaryAsync.when(
                data: (s) {
                  final stats = s.topProducts.firstWhere((tp) => tp.name == product.name, 
                    orElse: () => TopProduct(name: product.name, unit: product.baseUnit, revenue: 0, profit: 0, qty: 0, costPrice: 0, soldPrice: 0));
                  return AppCard(
                    child: Column(
                      children: [
                        _infoRow('Total Terjual', '${Formatters.decimal(stats.qty)} ${product.baseUnit}'),
                        _infoRow('Total Omzet', Formatters.currency(stats.revenue)),
                        _infoRow('Total Keuntungan', Formatters.currency(stats.profit), color: AppTheme.success, isBold: true),
                      ],
                    ),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const Text('Gagal memuat statistik'),
              ),

              if (product.units.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle('Satuan Jual Lainnya'),
                ...product.units.map((u) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.unitName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Konv: ${u.conversionRate} ${product.baseUnit}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                      Text(Formatters.currency(u.sellPrice), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    ],
                  ),
                )),
              ],
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String val, Color color) {
    return AppCard(
      color: color.withValues(alpha: 0.05),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 4),
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          Text(val, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textMuted)),
    );
  }
}
