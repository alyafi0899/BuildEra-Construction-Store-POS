import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/report_helper.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../products/providers/product_provider.dart';
import '../../../inventory/providers/restock_provider.dart';
import '../../../payment/providers/transaction_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../shared/models/transaction.dart';
import '../../../../shared/models/product.dart';
import '../../../inventory/models/restock_record.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _downloadReport(
    WidgetRef ref, 
    List<Transaction> txs, 
    List<Product> products, 
    List<RestockRecord> restocks,
    String period
  ) async {
    final settings = ref.read(settingsProvider);
    
    DateTime now = DateTime.now();
    List<Transaction> filtered;
    String periodName;

    switch (period) {
      case 'weekly':
        final lastWeek = now.subtract(const Duration(days: 7));
        filtered = txs.where((t) => t.createdAt.isAfter(lastWeek)).toList();
        periodName = 'Minggu_Ini';
        break;
      case 'monthly':
        filtered = txs.where((t) => t.createdAt.month == now.month && t.createdAt.year == now.year).toList();
        periodName = 'Bulan_Ini';
        break;
      case 'yearly':
        filtered = txs.where((t) => t.createdAt.year == now.year).toList();
        periodName = 'Tahun_Ini';
        break;
      default:
        filtered = txs;
        periodName = 'Semua_Data';
    }

    await ReportHelper.generateAndDownloadReport(
      transactions: filtered,
      products: products,
      restocks: restocks,
      periodName: periodName,
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(salesSummaryProvider);
    final transactionsAsync = ref.watch(transactionsProvider);
    final productsAsync = ref.watch(productsProvider);
    final restocksAsync = ref.watch(restockHistoryProvider);
    final currentPeriod = ref.watch(analyticsPeriodProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Header
          PageHeader(
            title: 'Analitik & Wawasan Bisnis',
            subtitle: 'Pemantauan performa finansial dan operasional toko',
            icon: Icons.analytics_rounded,
            actions: [
              if (transactionsAsync.hasValue && productsAsync.hasValue && restocksAsync.hasValue)
                PopupMenuButton<String>(
                  onSelected: (val) => _downloadReport(
                    ref, 
                    transactionsAsync.value!, 
                    productsAsync.value!, 
                    restocksAsync.value!,
                    val
                  ),
                  child: OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: const Text('Ekspor Laporan'),
                    style: OutlinedButton.styleFrom(
                      disabledForegroundColor: colorScheme.primary,
                      side: BorderSide(color: colorScheme.primary),
                    ),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'weekly', child: Text('Minggu Ini')),
                    const PopupMenuItem(value: 'monthly', child: Text('Bulan Ini')),
                    const PopupMenuItem(value: 'yearly', child: Text('Tahun Ini')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'all', child: Text('Semua Data')),
                  ],
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => ref.refresh(salesSummaryProvider),
                icon: Icon(Icons.refresh_rounded, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                tooltip: 'Refresh Data',
              ),
            ],
          ),

          // Period Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outline)),
            ),
            child: Row(
              children: [
                Text('Rentang Waktu:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                const SizedBox(width: 16),
                _periodChip('Hari Ini', AnalyticsPeriod.daily, currentPeriod, ref),
                const SizedBox(width: 8),
                _periodChip('Minggu Ini', AnalyticsPeriod.weekly, currentPeriod, ref),
                const SizedBox(width: 8),
                _periodChip('Bulan Ini', AnalyticsPeriod.monthly, currentPeriod, ref),
                const SizedBox(width: 8),
                _periodChip('Tahun Ini', AnalyticsPeriod.yearly, currentPeriod, ref),
                const SizedBox(width: 8),
                _periodChip('Semua', AnalyticsPeriod.all, currentPeriod, ref),
              ],
            ),
          ),

          Expanded(
            child: summaryAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: colorScheme.error))),
              data: (summary) => Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── SECTION 1: CORE KPIs ──────────────────────────────
                      const SectionHeader(title: 'Performa Finansial', icon: Icons.speed_rounded),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _gradientStatCard(
                          label: 'Laba Bersih',
                          value: summary.totalNetProfit,
                          subtitle: 'Dari ${Formatters.currency(summary.totalRevenue)} omzet',
                          colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.7)],
                          icon: Icons.auto_graph_rounded,
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _gradientStatCard(
                          label: 'Transaksi',
                          value: summary.totalTransactions.toDouble(),
                          subtitle: 'Total Nota Diterbitkan',
                          colors: [colorScheme.secondary, colorScheme.secondary.withValues(alpha: 0.7)],
                          icon: Icons.calendar_today_rounded,
                          isCurrency: false,
                        )),
                        const SizedBox(width: 16),
                        Expanded(child: _gradientStatCard(
                          label: 'Estimasi Laba Stok',
                          value: summary.potentialInventoryProfit,
                          subtitle: 'Potensi profit gudang',
                          colors: [const Color(0xFFF2994A), const Color(0xFFF2C94C)],
                          icon: Icons.inventory_2_rounded,
                        )),
                      ]),
                      const SizedBox(height: 32),

                      _buildFinancialInsights(summary),
                      const SizedBox(height: 32),

                      // ── SECTION 3: TRENDS & DISTRIBUTION ──────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: _buildRevenueChart(summary)),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: _buildPaymentMethodsChart(summary)),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // ── SECTION 4: TOP PRODUCTS ───────────────────────────
                      _buildTopProducts(summary),
                      const SizedBox(height: 32),

                      // ── SECTION 5: DAILY LOG ──────────────────────────────
                      const SectionHeader(title: 'Log Transaksi Harian', icon: Icons.history_edu_rounded),
                      const SizedBox(height: 16),
                      const _DailyDetailList(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String label, AnalyticsPeriod period, AnalyticsPeriod current, WidgetRef ref) {
    final active = period == current;
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => ref.read(analyticsPeriodProvider.notifier).setPeriod(period),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: active ? colorScheme.primary.withValues(alpha: 0.15) : colorScheme.surfaceContainerHighest,
          border: Border.all(color: active ? colorScheme.primary : colorScheme.outline),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, 
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          color: active ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
        )),
      ),
    );
  }

  Widget _gradientStatCard({
    required String label,
    required double value,
    required String subtitle,
    required List<Color> colors,
    required IconData icon,
    bool isCurrency = true,
  }) {
    return Container(
      height: 140, 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
            ],
          ),
          const SizedBox(height: 12),
          Text(isCurrency ? Formatters.currency(value) : value.toInt().toString(), 
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFinancialInsights(SalesSummary summary) {
    final recommendedRestock = summary.totalRevenue * 0.65;
    final recommendedOther = summary.totalNetProfit * 0.15;
    final maxWithdrawal = summary.totalNetProfit * 0.85;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Manajemen Arus Kas Cerdas', icon: Icons.account_balance_rounded),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _insightCard(
                        title: 'Total Omzet',
                        subtitle: 'Pendapatan kotor periode ini',
                        value: summary.totalRevenue,
                        color: const Color(0xFF3498DB),
                        icon: Icons.payments_rounded,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _insightCard(
                        title: 'Rekomendasi Re-stock',
                        subtitle: 'Alokasi ideal belanja (65% Omzet)',
                        value: recommendedRestock,
                        color: colorScheme.primary,
                        icon: Icons.shopping_cart_checkout_rounded,
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _insightCard(
                        title: 'Dana Cadangan',
                        subtitle: 'Simpanan tak terduga (15% Net)',
                        value: recommendedOther,
                        color: const Color(0xFFF39C12),
                        icon: Icons.savings_rounded,
                      )),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 120, 
                          child: AppCard(
                            color: const Color(0xFF2ECC71).withValues(alpha: 0.05),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('TAKE HOME PROFIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Color(0xFF2ECC71))),
                                const SizedBox(height: 8),
                                Text(Formatters.currency(maxWithdrawal), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF2ECC71))),
                                Text('Rekomendasi: 85% Laba Bersih', style: TextStyle(fontSize: 9, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 1,
              child: _buildConsolidatedAlerts(summary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConsolidatedAlerts(SalesSummary summary) {
    final hasAlerts = summary.unpaidSupplierDetails.isNotEmpty || summary.unpaidShippingDetails.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    final alertColor = hasAlerts ? colorScheme.error : const Color(0xFF2ECC71);

    return Container(
      height: 256, 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: alertColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: alertColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(hasAlerts ? Icons.warning_amber_rounded : Icons.check_circle_rounded, color: alertColor, size: 20),
            const SizedBox(width: 8),
            Text('STATUS TAGIHAN', style: TextStyle(color: alertColor, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
          const SizedBox(height: 16),
          if (!hasAlerts)
            Text('Semua tagihan lunas! Arus kas belanja aman.', style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6)))
          else ...[
            Text('PENDING:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.4))),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  ...summary.unpaidSupplierDetails.take(3).map((e) => _miniAlertRow(e.entityName, e.remainingAmount)),
                  ...summary.unpaidShippingDetails.take(2).map((e) => _miniAlertRow(e.entityName, e.remainingAmount)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniAlertRow(String name, double amt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
          Text(Formatters.currency(amt), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.error)),
        ],
      ),
    );
  }

  Widget _insightCard({required String title, required String subtitle, required double value, required Color color, required IconData icon}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 120, 
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          Text(Formatters.currency(value), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 9, color: colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ),
    );
  }

  Widget _buildRevenueChart(SalesSummary summary) {
    bool isDaily = summary.period == AnalyticsPeriod.daily;
    final colorScheme = Theme.of(context).colorScheme;
    
    List<MapEntry<dynamic, double>> entries;
    if (isDaily) {
      entries = List.generate(13, (i) {
        final hour = i + 6;
        return MapEntry(hour, summary.netProfitByHour[hour] ?? 0.0);
      });
    } else {
      entries = summary.netProfitByDay.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
    }

    if (entries.isEmpty) return const SizedBox();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: isDaily ? 'Tren Keuntungan Bersih (Per Jam)' : 'Tren Keuntungan Bersih', 
            icon: Icons.insights_rounded
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: entries.every((e) => e.value == 0) ? 100 : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.3,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => colorScheme.surfaceContainerHighest,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    String label;
                    if (isDaily) {
                      label = '${group.x.toInt().toString().padLeft(2, '0')}:00';
                    } else {
                      label = entries[groupIndex].key.toString();
                    }
                    return BarTooltipItem(
                      '$label\n',
                      TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold),
                      children: [
                        TextSpan(
                          text: Formatters.currency(rod.toY),
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: 1, 
                  getTitlesWidget: (val, _) {
                    if (isDaily) {
                      if (val < 6 || val > 18) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8), 
                        child: Text('${val.toInt().toString().padLeft(2, '0')}:00', style: TextStyle(fontSize: 8, color: colorScheme.onSurface.withValues(alpha: 0.6)))
                      );
                    }

                    if (val.toInt() < 0 || val.toInt() >= entries.length) return const SizedBox();
                    final label = entries[val.toInt()].key.toString().split('-').last;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8), 
                      child: Text(label, style: TextStyle(fontSize: 9, color: colorScheme.onSurface.withValues(alpha: 0.6)))
                    );
                  },
                )),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: entries.asMap().entries.map((e) => BarChartGroupData(
                x: isDaily ? (e.value.key as int) : e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.value, 
                    color: colorScheme.primary, 
                    width: isDaily ? 12 : 20, 
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4))
                  )
                ],
              )).toList(),
            )),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsChart(SalesSummary summary) {
    final cash = summary.revenueByPayment['Tunai'] ?? 0;
    final qris = summary.revenueByPayment['QRIS'] ?? 0;
    final debt = summary.revenueByPayment['Piutang'] ?? 0;
    final total = cash + qris + debt;
    final colorScheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Metode Pembayaran', icon: Icons.pie_chart_rounded),
          const SizedBox(height: 24),
          if (total == 0) const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('Belum ada data')))
          else Column(children: [
            SizedBox(height: 180, child: PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 40, sections: [
              PieChartSectionData(value: cash, title: '${(cash/total*100).toStringAsFixed(0)}%', color: const Color(0xFF2ECC71), radius: 50, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              PieChartSectionData(value: qris, title: '${(qris/total*100).toStringAsFixed(0)}%', color: const Color(0xFF3498DB), radius: 50, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
              PieChartSectionData(value: debt, title: '${(debt/total*100).toStringAsFixed(0)}%', color: colorScheme.primary, radius: 50, titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ]))),
            const SizedBox(height: 24),
            _legendItem('Tunai', cash, const Color(0xFF2ECC71)),
            _legendItem('QRIS', qris, const Color(0xFF3498DB)),
            _legendItem('Piutang', debt, colorScheme.primary),
          ]),
        ],
      ),
    );
  }

  Widget _legendItem(String label, double val, Color color) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(fontSize: 13)),
      const Spacer(),
      Text(Formatters.currency(val), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    ]));
  }

  Widget _buildTopProducts(SalesSummary summary) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Top 5 Produk Terlaris', icon: Icons.star_rounded),
          const SizedBox(height: 16),
          if (summary.topProducts.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Belum ada data penjualan')))
          else
            ...summary.topProducts.take(5).map((p) {
              final idx = summary.topProducts.indexOf(p) + 1;
              return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [
                Container(width: 24, height: 24, decoration: BoxDecoration(color: idx <= 3 ? colorScheme.primary : colorScheme.surfaceContainerHighest, shape: BoxShape.circle),
                  child: Center(child: Text('$idx', style: TextStyle(color: idx <= 3 ? colorScheme.onPrimary : colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.bold)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${Formatters.decimal(p.qty)} ${p.unit} terjual', style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6))),
                ])),
                Text(Formatters.currency(p.revenue), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: colorScheme.primary)),
              ]));
            }),
        ],
      ),
    );
  }
}

class _DailyDetailList extends ConsumerWidget {
  const _DailyDetailList();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(salesSummaryProvider);
    return summaryAsync.when(
      data: (summary) => Column(children: summary.dailyDetails.map((d) => _DailyRow(detail: d)).toList()),
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _DailyRow extends StatelessWidget {
  final DailySummary detail;
  const _DailyRow({required this.detail});

  void _downloadDailyReport(WidgetRef ref) async {
    final settings = ref.read(settingsProvider);
    final products = ref.read(productsProvider).asData?.value ?? [];
    final restocks = ref.read(restockHistoryProvider).asData?.value ?? [];
    await ReportHelper.generateAndDownloadReport(
      transactions: detail.transactions,
      products: products,
      restocks: restocks,
      periodName: 'Harian_${detail.date.replaceAll('-', '')}',
      settings: settings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outline),
        ),
        child: Consumer(builder: (context, ref, child) {
          return ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            title: Row(children: [
              SizedBox(width: 120, child: Text(detail.date, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              const Spacer(),
              _miniTitleStat(context, 'Omzet', detail.revenue, colorScheme.onSurface),
              const SizedBox(width: 24),
              _miniTitleStat(context, 'Profit', detail.netProfit, const Color(0xFF2ECC71)),
              const SizedBox(width: 24),
              _miniTitleStat(context, 'Nota', detail.transactionCount.toDouble(), const Color(0xFF3498DB), isCurrency: false),
            ]),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(onPressed: () => _downloadDailyReport(ref), icon: Icon(Icons.picture_as_pdf_rounded, size: 20, color: colorScheme.primary), tooltip: 'Ekspor PDF Harian'),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ]),
            children: [
              Container(padding: const EdgeInsets.all(24), color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.4), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _breakdownBox(context, 'TUNAI', detail.cashTotal, const Color(0xFF2ECC71), Icons.payments_rounded),
                  _breakdownBox(context, 'QRIS', detail.qrisTotal, const Color(0xFF3498DB), Icons.qr_code_scanner_rounded),
                  _breakdownBox(context, 'PIUTANG', detail.debtTotal, colorScheme.primary, Icons.account_balance_wallet_rounded),
                ]),
                const SizedBox(height: 32),
                Align(alignment: Alignment.centerLeft, child: Text('LOG AUDIT TRANSAKSI:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: colorScheme.onSurface.withValues(alpha: 0.4), letterSpacing: 1.2))),
                const SizedBox(height: 16),
                ...detail.transactions.map((tx) => _DetailedTxAuditTile(tx: tx)),
              ])),
            ],
          );
        }),
      ),
    );
  }

  Widget _miniTitleStat(BuildContext context, String l, double v, Color c, {bool isCurrency = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(l, style: TextStyle(fontSize: 9, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.bold)),
      Text(isCurrency ? Formatters.currency(v) : v.toInt().toString(), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c)),
    ]);
  }

  Widget _breakdownBox(BuildContext context, String label, double val, Color color, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 6), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.15))),
        child: Column(children: [Icon(icon, color: color, size: 20), const SizedBox(height: 8), Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.6))),
          const SizedBox(height: 4), Text(Formatters.currency(val), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900))])));
  }
}

class _DetailedTxAuditTile extends StatelessWidget {
  final Transaction tx;
  const _DetailedTxAuditTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Text(tx.invoiceNumber, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(width: 12),
                StatusChip(label: tx.paymentMethod.toUpperCase(), color: colorScheme.onSurface.withValues(alpha: 0.5)),
                if (tx.customerName != null) ...[const SizedBox(width: 8), Text('• ${tx.customerName}', style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.6)))],
                const Spacer(),
                Text('Total: ${Formatters.currency(tx.total)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [_th(context, 'Produk', 5), _th(context, 'Qty', 2, align: TextAlign.center), _th(context, 'Modal', 3, align: TextAlign.right), _th(context, 'Jual', 3, align: TextAlign.right), _th(context, 'Profit', 3, align: TextAlign.right)]),
          ),
          ...tx.items.map((item) {
            final profit = item.subtotal - (item.costPrice * item.quantity);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(children: [
                Expanded(flex: 5, child: Text(item.productName, style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.8)))),
                Expanded(flex: 2, child: Text('${Formatters.decimal(item.quantity)} ${item.unitName}', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.6)))),
                Expanded(flex: 3, child: Text(Formatters.currency(item.costPrice), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.4)))),
                Expanded(flex: 3, child: Text(Formatters.currency(item.soldPrice), textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: colorScheme.onSurface))),
                Expanded(flex: 3, child: Text(Formatters.currency(profit), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2ECC71)))),
              ]),
            );
          }),
          if (tx.notes != null && tx.notes!.isNotEmpty) ...[
            Padding(padding: const EdgeInsets.all(16), child: Divider(height: 1, color: colorScheme.outline)),
            Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text('Catatan: ${tx.notes}', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: colorScheme.onSurface.withValues(alpha: 0.5)))),
          ] else const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _th(BuildContext context, String label, int flex, {TextAlign align = TextAlign.left}) {
    return Expanded(flex: flex, child: Text(label, textAlign: align, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), letterSpacing: 0.5)));
  }
}
