import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/providers/product_provider.dart';
import '../../../inventory/providers/restock_provider.dart';
import '../../../payment/providers/transaction_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/widgets/security_gate.dart';
import '../../../../core/providers/navigation_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(salesSummaryProvider);
    final currentPeriod = ref.watch(analyticsPeriodProvider);
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: PinGate(
        child: Column(
          children: [
            PageHeader(
              title: 'Ringkasan Bisnis',
              subtitle: 'Performa toko hari ini',
              icon: Icons.dashboard_rounded,
              actions: [
                IconButton(
                  onPressed: () => ref.refresh(salesSummaryProvider),
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                ),
              ],
            ),

            // Quick Actions (Mobile specific or prominent)
            if (isMobile) _buildQuickActions(context),

            Expanded(
              child: summaryAsync.when(
                loading: () => const AppLoading(),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (summary) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KPI Grid
                      LayoutBuilder(builder: (context, constraints) {
                        int crossAxisCount = constraints.maxWidth < 600 ? 1 : (constraints.maxWidth < 900 ? 2 : 3);
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 2.2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          children: [
                            StatCard(
                              label: 'Laba Bersih',
                              value: Formatters.currency(summary.totalNetProfit),
                              icon: Icons.auto_graph_rounded,
                              accentColor: AppTheme.success,
                              subtitle: 'Omzet: ${Formatters.currency(summary.totalRevenue)}',
                            ),
                            StatCard(
                              label: 'Transaksi',
                              value: summary.totalTransactions.toString(),
                              icon: Icons.receipt_long_rounded,
                              accentColor: AppTheme.info,
                              subtitle: 'Nota Terbit',
                            ),
                            StatCard(
                              label: 'Potensi Profit Stok',
                              value: Formatters.currency(summary.potentialInventoryProfit),
                              icon: Icons.inventory_2_rounded,
                              accentColor: AppTheme.warning,
                              subtitle: 'Nilai Barang Gudang',
                            ),
                          ],
                        );
                      }),
                      
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Wawasan Keuangan', icon: Icons.insights_rounded),
                      _buildMiniChart(summary, isMobile),
                      
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Top Produk', icon: Icons.star_rounded),
                      _buildTopProductsList(summary),
                      
                      const SizedBox(height: 80), // Space for bottom bar
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: isMobile 
        ? FloatingActionButton(
            onPressed: () => ref.read(navigationIndexProvider.notifier).setIndex(0), // Go to Cashier
            backgroundColor: AppTheme.primary,
            child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
          )
        : null,
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _quickActionItem(context, 'Kasir Baru', Icons.point_of_sale_rounded, 0),
          _quickActionItem(context, 'Tambah Produk', Icons.add_box_rounded, 1),
          _quickActionItem(context, 'Stok Opname', Icons.inventory_rounded, 2),
          _quickActionItem(context, 'Cek Piutang', Icons.account_balance_wallet_rounded, 4),
        ],
      ),
    );
  }

  Widget _quickActionItem(BuildContext context, String label, IconData icon, int navIdx) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 12),
      child: InkWell(
        onTap: () => ref.read(navigationIndexProvider.notifier).setIndex(navIdx),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniChart(SalesSummary summary, bool isMobile) {
    // Simplified version of the revenue chart for mobile
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tren Profit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: summary.netProfitByHour.values.isEmpty ? 100000 : summary.netProfitByHour.values.reduce((a, b) => a > b ? a : b) * 1.5,
                barGroups: summary.netProfitByHour.entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [
                    BarChartRodData(toY: e.value, color: AppTheme.primary, width: 12, borderRadius: BorderRadius.circular(4)),
                  ],
                )).toList(),
                titlesData: const FlTitlesData(show: false),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductsList(SalesSummary summary) {
    if (summary.topProducts.isEmpty) return const Text('Belum ada data');
    
    return Column(
      children: summary.topProducts.take(5).map((p) => AppCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: AppTheme.surfaceAlt, shape: BoxShape.circle),
              child: Center(child: Text('${summary.topProducts.indexOf(p) + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('${Formatters.decimal(p.qty)} terjual', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ]),
            ),
            Text(Formatters.currency(p.revenue), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
          ],
        ),
      )).toList(),
    );
  }
}
