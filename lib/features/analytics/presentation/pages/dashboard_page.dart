import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/providers/product_provider.dart';
import '../../../payment/providers/transaction_provider.dart';
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
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: PinGate(
        child: Column(
          children: [
            PageHeader(
              title: 'Dashboard Manager',
              subtitle: 'Analitik performa toko & operasional',
              icon: Icons.analytics_rounded,
              actions: [
                IconButton(
                  onPressed: () => ref.refresh(salesSummaryProvider),
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.primary),
                ),
              ],
            ),

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
                              label: 'Total Transaksi',
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
                      const SectionHeader(title: 'Wawasan Arus Kas', icon: Icons.account_balance_rounded),
                      _buildFinancialInsights(summary),
                      
                      if (summary.unpaidSupplierDetails.isNotEmpty || summary.unpaidShippingDetails.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const SectionHeader(title: 'Peringatan Tagihan', icon: Icons.warning_amber_rounded, color: AppTheme.danger),
                        _buildBillAlerts(summary),
                      ],

                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Tren Keuntungan', icon: Icons.insights_rounded),
                      _buildMiniChart(summary),
                      
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Expanded(child: SectionHeader(title: 'Log Harian', icon: Icons.history_edu_rounded)),
                          TextButton(
                            onPressed: () => _showDailyAudit(context, summary),
                            child: const Text('Detail Audit'),
                          ),
                        ],
                      ),
                      _buildMiniAuditList(summary),

                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Produk Terlaris', icon: Icons.star_rounded),
                      _buildTopProductsList(summary),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _quickActionItem(context, 'Tambah Produk', Icons.add_box_rounded, 1),
          _quickActionItem(context, 'Cek Stok', Icons.inventory_rounded, 2),
          _quickActionItem(context, 'Riwayat Jual', Icons.receipt_long_rounded, 3),
          _quickActionItem(context, 'Daftar Piutang', Icons.people_rounded, 4),
          _quickActionItem(context, 'Tagihan Operas.', Icons.receipt_rounded, 5),
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

  Widget _buildFinancialInsights(SalesSummary summary) {
    final recommendedRestock = summary.totalRevenue * 0.65;
    final maxWithdrawal = summary.totalNetProfit * 0.85;

    return AppCard(
      color: AppTheme.primary.withValues(alpha: 0.05),
      child: Column(
        children: [
          _insightRow('Estimasi Re-stock', recommendedRestock, 'Alokasi Belanja Barang (65%)', Icons.shopping_cart_checkout_rounded, AppTheme.primary),
          const Divider(height: 24),
          _insightRow('Take Home Profit', maxWithdrawal, 'Dana Aman Ditarik (85%)', Icons.savings_rounded, AppTheme.success),
        ],
      ),
    );
  }

  Widget _insightRow(String label, double val, String desc, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(desc, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ),
        Text(Formatters.currency(val), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildBillAlerts(SalesSummary summary) {
    final alerts = [...summary.unpaidSupplierDetails, ...summary.unpaidShippingDetails];
    return Column(
      children: alerts.take(3).map((a) => AppCard(
        margin: const EdgeInsets.only(bottom: 8),
        color: AppTheme.danger.withValues(alpha: 0.05),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(a.entityName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis)),
            Text(Formatters.currency(a.remainingAmount), style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold)),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildMiniAuditList(SalesSummary summary) {
    if (summary.dailyDetails.isEmpty) return const Text('Belum ada data audit');
    final latest = summary.dailyDetails.first;
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              Text(latest.date, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              StatusChip(label: '${latest.transactionCount} Nota', color: AppTheme.info),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _auditSmallStat('OMZET', latest.revenue, AppTheme.primary),
              _auditSmallStat('PROFIT', latest.netProfit, AppTheme.success),
              _auditSmallStat('PIUTANG', latest.debtTotal, AppTheme.warning),
            ],
          ),
        ],
      ),
    );
  }

  Widget _auditSmallStat(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
        Text(Formatters.currency(val), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  void _showDailyAudit(BuildContext context, SalesSummary summary) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppTheme.bg,
      builder: (_) => _DailyAuditSheet(summary: summary),
    );
  }

  Widget _buildMiniChart(SalesSummary summary) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Grafik Profit Per Jam', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: summary.netProfitByHour.values.isEmpty ? 1000 : summary.netProfitByHour.values.reduce((a, b) => a > b ? a : b) * 1.5,
                barGroups: summary.netProfitByHour.entries.map((e) => BarChartGroupData(
                  x: e.key,
                  barRods: [BarChartRodData(toY: e.value, color: AppTheme.primary, width: 12, borderRadius: BorderRadius.circular(4))],
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
    if (summary.topProducts.isEmpty) return const Text('Belum ada data produk terlaris');
    return Column(
      children: summary.topProducts.take(5).map((p) => AppCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: const BoxDecoration(color: AppTheme.surfaceAlt, shape: BoxShape.circle),
              child: Center(child: Text('${summary.topProducts.indexOf(p) + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${Formatters.decimal(p.qty)} terjual', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              ]),
            ),
            Text(Formatters.currency(p.revenue), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13)),
          ],
        ),
      )).toList(),
    );
  }
}

class _DailyAuditSheet extends StatelessWidget {
  final SalesSummary summary;
  const _DailyAuditSheet({required this.summary});

  @override
  Widget build(BuildContext context) {
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
              const Text('Audit Transaksi Harian', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: summary.dailyDetails.length,
            itemBuilder: (context, i) {
              final day = summary.dailyDetails[i];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(day.date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const Spacer(),
                        StatusChip(label: '${day.transactionCount} Nota', color: AppTheme.info),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _miniStat('Omzet', day.revenue, AppTheme.primary),
                        _miniStat('Profit', day.netProfit, AppTheme.success),
                        _miniStat('Tunai', day.cashTotal, AppTheme.textMuted),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String label, double val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        Text(Formatters.currency(val), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
