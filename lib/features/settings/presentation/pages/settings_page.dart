// lib/features/settings/presentation/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../payment/presentation/providers/transaction_provider.dart';
import '../../../products/presentation/providers/product_provider.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products     = ref.watch(allProductsProvider);
    final todaySales   = ref.watch(todaySalesProvider);
    final todayCount   = ref.watch(todayTransactionCountProvider);
    final txList       = ref.watch(transactionListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: const Text('Pengaturan & Info',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Toko
              _Card(title: 'Informasi Toko', icon: Icons.store_rounded, children: [
                _Row('Nama Toko',    AppConstants.storeName),
                _Row('Alamat',       AppConstants.storeAddress),
                _Row('Telepon',      AppConstants.storePhone),
                _Row('Tarif PPN',    '${(AppConstants.taxRate * 100).toInt()}%'),
                _Row('Batas Stok Rendah', '${AppConstants.lowStockThreshold} unit'),
              ]),
              const SizedBox(height: 16),

              // App info
              _Card(title: 'Informasi Aplikasi', icon: Icons.info_rounded, children: [
                _Row('Nama Aplikasi',    AppConstants.appName),
                _Row('Versi',            AppConstants.appVersion),
                const _Row('Platform',         'Web / Desktop (Flutter)'),
                const _Row('Database',         'Hive (NoSQL Lokal)'),
                const _Row('State Management', 'Riverpod'),
              ]),
              const SizedBox(height: 16),

              // DB stats
              _Card(title: 'Statistik Database', icon: Icons.storage_rounded, children: [
                _Row('Total Produk',           '${products.length} produk'),
                _Row('Produk Aktif',           '${products.where((p) => !p.isOutOfStock).length} produk'),
                _Row('Total Satuan Terdaftar', '${products.fold(0, (s, p) => s + p.units.length)} satuan'),
                _Row('Total Transaksi',        '${txList.length} transaksi'),
                _Row('Penjualan Hari Ini',     AppFormatters.formatCurrency(todaySales),    valueColor: AppColors.success),
                _Row('Transaksi Hari Ini',     '$todayCount transaksi'),
                _Row('Total Omzet Keseluruhan', AppFormatters.formatCurrency(txList.fold(0.0, (s, t) => s + t.totalAmount)), valueColor: AppColors.primary),
              ]),
              const SizedBox(height: 16),

              // Satuan
              _Card(title: 'Satuan yang Didukung', icon: Icons.straighten_rounded, children: [
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: AppConstants.baseUnits.map((u) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(u, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                  )).toList(),
                ),
              ]),
              const SizedBox(height: 16),

              // Keyboard shortcuts
              _Card(title: 'Pintasan Keyboard', icon: Icons.keyboard_rounded, children: const [
                const _Row('Scan Barcode',       'Scan USB Scanner → Enter'),
                const _Row('Cari Produk',        'Klik field pencarian'),
                const _Row('Konfirmasi Qty',     'Enter pada field jumlah'),
                const _Row('Tutup Dialog',       'Esc'),
              ]),

              const SizedBox(height: 24),
              Center(child: Column(children: [
                const Icon(Icons.construction, color: AppColors.primary, size: 32),
                const SizedBox(height: 8),
                Text('${AppConstants.appName} v${AppConstants.appVersion}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Built for ${AppConstants.storeName}',
                    style: const TextStyle(color: AppColors.textDisabled, fontSize: 11)),
                const SizedBox(height: 4),
                Text('© ${DateTime.now().year} • Flutter POS System · Hive Database',
                    style: const TextStyle(color: AppColors.textDisabled, fontSize: 10)),
              ])),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  _Card({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
          child: Row(children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 200,
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
        Expanded(child: Text(value, style: TextStyle(
          color: valueColor ?? AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
