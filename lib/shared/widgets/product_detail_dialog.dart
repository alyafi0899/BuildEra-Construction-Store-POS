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
    return showDialog(
      context: context,
      builder: (_) => ProductDetailDialog(product: product),
    );
  }

  void _showFullImage(BuildContext context) {
    if (product.imagePath == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: ProductImage(imagePath: product.imagePath, size: 400),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(salesSummaryProvider);
    final f = product.financials;
    final unitProfit = product.basePrice - product.costPrice;
    final margin =
        product.costPrice > 0 ? (unitProfit / product.costPrice) * 100 : 0.0;

    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 700;

    Widget buildMainHeader() {
      final imageWidget = GestureDetector(
        onTap: () => _showFullImage(context),
        child: ProductImage(imagePath: product.imagePath, size: isCompact ? 160 : 220),
      );

      final mainInfoWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(product.category.toUpperCase(),
                  style: const TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.2)),
              const Spacer(),
              if (f.supplierName != null)
                _miniBadge(Icons.business_rounded, f.supplierName!),
            ],
          ),
          const SizedBox(height: 8),
          Text(product.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w900)),
          if (product.barcode != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    size: 16, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Text(product.barcode!,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 14)),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _statItem(context, 'Stok Tersedia',
                  '${Formatters.decimal(product.stock)} ${product.baseUnit}',
                  color: product.isLowStock
                      ? AppTheme.warning
                      : AppTheme.success),
              const SizedBox(width: 24),
              _statItem(context, 'Harga Jual',
                  Formatters.currency(product.basePrice),
                  color: AppTheme.accent),
            ],
          ),
        ],
      );

      if (isCompact) {
        return Column(
          children: [
            Center(child: imageWidget),
            const SizedBox(height: 16),
            mainInfoWidget,
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          imageWidget,
          const SizedBox(width: 32),
          Expanded(child: mainInfoWidget),
        ],
      );
    }

    Widget buildFinancialDetails() {
      final costSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SubLabel('COST BREAKDOWN'),
          const SizedBox(height: 12),
          _detailRow(
              'Harga Beli Supplier', Formatters.currency(f.supplierPrice)),
          _detailRow(
              'Ongkos Kirim', Formatters.currency(f.supplierShippingCost)),
          const Divider(height: 20, thickness: 0.5),
          _detailRow('Total Modal (Unit)', Formatters.currency(product.costPrice),
              isBold: true),
          const SizedBox(height: 24),
          const _SubLabel('PRICING & MARGIN'),
          const SizedBox(height: 12),
          _detailRow('Harga Jual Dasar', Formatters.currency(product.basePrice)),
          _detailRow('Profit Bersih / Unit', Formatters.currency(unitProfit),
              color: AppTheme.success),
          _detailRow('Profit Margin', '${margin.toStringAsFixed(1)}%',
              color: AppTheme.info),
        ],
      );

      final paymentSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SubLabel('PAYMENT STATUS'),
          const SizedBox(height: 12),
          _paymentStatusItem('Barang (Supplier)', f.supplierPaymentStatus),
          const SizedBox(height: 8),
          _paymentStatusItem('Ongkir (Ekspedisi)', f.shippingPaymentStatus),
          const SizedBox(height: 24),
          const _SubLabel('SALES STATISTICS'),
          const SizedBox(height: 12),
          summaryAsync.when(
            data: (s) {
              final stats = s.topProducts.firstWhere(
                  (tp) => tp.name == product.name,
                  orElse: () => TopProduct(
                      name: product.name,
                      unit: product.baseUnit,
                      revenue: 0,
                      profit: 0,
                      qty: 0,
                      costPrice: 0,
                      soldPrice: 0));

              return Column(
                children: [
                  _detailRow('Unit Terjual',
                      '${Formatters.decimal(stats.qty)} ${product.baseUnit}'),
                  _detailRow('Total Omzet', Formatters.currency(stats.revenue)),
                  _detailRow(
                      'Total Net Profit', Formatters.currency(stats.profit),
                      color: AppTheme.success, isBold: true),
                ],
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => const Text('Gagal memuat statistik'),
          ),
        ],
      );

      if (isCompact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            costSection,
            const Divider(height: 32),
            paymentSection,
          ],
        );
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: costSection),
          const SizedBox(width: 32),
          Expanded(flex: 3, child: paymentSection),
        ],
      );
    }

    final dialogContent = SingleChildScrollView(
      padding: EdgeInsets.all(isCompact ? 16 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildMainHeader(),
          const Divider(height: 36),
          buildFinancialDetails(),
          if (product.units.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SubLabel('SATUAN JUAL LAINNYA'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: product.units
                  .map((u) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u.unitName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(Formatters.currency(u.sellPrice),
                                style: const TextStyle(
                                    color: AppTheme.accent, fontSize: 13)),
                            Text('Konv: ${u.conversionRate} ${product.baseUnit}',
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.textMuted)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.surfaceAlt,
                foregroundColor: AppTheme.textPrimary,
              ),
              child: const Text('TUTUP'),
            ),
          ),
        ],
      ),
    );

    if (isCompact) {
      return Dialog.fullscreen(
        backgroundColor: AppTheme.surface,
        child: Scaffold(
          backgroundColor: AppTheme.surface,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            elevation: 0,
            title: const Text('Detail Produk'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: dialogContent,
        ),
      );
    }

    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 800,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: dialogContent,
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, String value,
      {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color ?? AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _detailRow(String label, String value,
      {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  color: color ?? AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _paymentStatusItem(String label, PaymentStatus status) {
    Color badgeColor;
    String statusText;

    switch (status) {
      case PaymentStatus.paid:
        badgeColor = AppTheme.success;
        statusText = 'LUNAS';
        break;
      case PaymentStatus.partial:
        badgeColor = AppTheme.warning;
        statusText = 'SEBAGIAN';
        break;
      case PaymentStatus.unpaid:
        badgeColor = AppTheme.danger;
        statusText = 'BELUM LUNAS';
        break;
      case PaymentStatus.notApplicable:
        badgeColor = AppTheme.textMuted;
        statusText = 'N/A';
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
          ),
          child: Text(
            statusText,
            style: TextStyle(
                color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _miniBadge(IconData icon, String text) {
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
          Icon(icon, size: 12, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(text,
              style:
                  const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _SubLabel extends StatelessWidget {
  final String title;
  const _SubLabel(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: AppTheme.accent,
        letterSpacing: 1.2,
      ),
    );
  }
}
