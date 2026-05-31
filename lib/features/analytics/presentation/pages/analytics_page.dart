import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../payment/providers/transaction_provider.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(salesSummaryProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(24),
          color:   AppTheme.surface,
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Analitik Penjualan', style: Theme.of(context).textTheme.headlineLarge),
              Text('Ringkasan performa toko secara keseluruhan', style: Theme.of(context).textTheme.bodyMedium),
            ]),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => ref.refresh(salesSummaryProvider),
              icon:  const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          ]),
        ),

        Expanded(
          child: summaryAsync.when(
            loading: () => const AppLoading(),
            error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
            data: (summary) => Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── KPI Row ────────────────────────────────────────────
                    Row(children: [
                      Expanded(child: StatCard(
                        label:   'Total Pendapatan',
                        value:   Formatters.currency(summary.totalRevenue),
                        icon:    Icons.attach_money_rounded,
                        subtitle: 'Semua waktu',
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: StatCard(
                        label:       'Total Transaksi',
                        value:       summary.totalTransactions.toString(),
                        icon:        Icons.receipt_long_rounded,
                        accentColor: AppTheme.info,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: StatCard(
                        label:       'Rata-rata Order',
                        value:       Formatters.currency(summary.avgOrderValue),
                        icon:        Icons.trending_up_rounded,
                        accentColor: AppTheme.success,
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: StatCard(
                        label:       'Produk Terjual',
                        value:       summary.topProducts.length.toString(),
                        icon:        Icons.inventory_2_rounded,
                        accentColor: AppTheme.warning,
                        subtitle:    'SKU aktif',
                      )),
                    ]),
                    const SizedBox(height: 24),

                    // ── Charts Row ─────────────────────────────────────────
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Revenue bar chart
                      Expanded(
                        flex: 3,
                        child: AppCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SectionHeader(
                              title: 'Pendapatan Harian',
                              icon:  Icons.bar_chart_rounded,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 260,
                              child: summary.revenueByDay.isEmpty
                                  ? const Center(child: Text('Belum ada data transaksi', style: TextStyle(color: AppTheme.textMuted)))
                                  : _RevenueBarChart(data: summary.revenueByDay),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Payment pie chart
                      Expanded(
                        flex: 2,
                        child: AppCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const SectionHeader(
                              title: 'Metode Pembayaran',
                              icon:  Icons.pie_chart_rounded,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 260,
                              child: summary.revenueByPayment.isEmpty
                                  ? const Center(child: Text('Belum ada data transaksi', style: TextStyle(color: AppTheme.textMuted)))
                                  : _PaymentPieChart(data: summary.revenueByPayment),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 24),

                    // ── Top Products ───────────────────────────────────────
                    AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SectionHeader(
                          title: 'Top 10 Produk Terlaris',
                          icon:  Icons.star_rounded,
                        ),
                        const SizedBox(height: 20),
                        if (summary.topProducts.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                'Lakukan transaksi pertama untuk melihat analitik produk',
                                style: TextStyle(color: AppTheme.textMuted),
                              ),
                            ),
                          )
                        else
                          ...summary.topProducts.asMap().entries.map((entry) {
                            final rank = entry.key + 1;
                            final prod = entry.value;
                            final maxRev = summary.topProducts.first.revenue;
                            final ratio = maxRev > 0 ? prod.revenue / maxRev : 0.0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(children: [
                                // Rank badge
                                SizedBox(
                                  width: 32,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:        rank <= 3
                                          ? AppTheme.accent.withValues(alpha: 0.2)
                                          : AppTheme.surfaceAlt,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#$rank',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:      rank <= 3 ? AppTheme.accent : AppTheme.textMuted,
                                        fontWeight: FontWeight.w700,
                                        fontSize:   11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Name + bar
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(
                                    prod.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: LinearProgressIndicator(
                                      value:           ratio,
                                      backgroundColor: AppTheme.border,
                                      valueColor: AlwaysStoppedAnimation(
                                        rank == 1 ? AppTheme.accent
                                            : rank == 2 ? AppTheme.accentLight
                                            : rank == 3 ? AppTheme.warning
                                            : AppTheme.textMuted,
                                      ),
                                      minHeight: 5,
                                    ),
                                  ),
                                ])),
                                const SizedBox(width: 16),
                                // Revenue
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(
                                    Formatters.currency(prod.revenue),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13),
                                  ),
                                  Text(
                                    '${Formatters.decimal(prod.qty)} terjual',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ]),
                              ]),
                            );
                          }),
                      ]),
                    ),
                    const SizedBox(height: 24),

                    // ── Daily breakdown table ──────────────────────────────
                    AppCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SectionHeader(
                          title: 'Rincian Per Hari',
                          icon:  Icons.calendar_today_rounded,
                        ),
                        const SizedBox(height: 16),
                        if (summary.revenueByDay.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('Belum ada data', style: TextStyle(color: AppTheme.textMuted))),
                          )
                        else ...[
                          // Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color:        AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(children: [
                              Expanded(child: Text('Tanggal', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))),
                              Text('Total Pendapatan', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                            ]),
                          ),
                          const SizedBox(height: 4),
                          ...(() {
                            final sorted = summary.revenueByDay.entries.toList()
                              ..sort((a, b) => b.key.compareTo(a.key));
                            return sorted.map((e) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppTheme.border, width: 0.5)),
                              ),
                              child: Row(children: [
                                Expanded(child: Text(e.key, style: Theme.of(context).textTheme.bodyMedium)),
                                Text(
                                  Formatters.currency(e.value),
                                  style: const TextStyle(
                                    color:      AppTheme.accent,
                                    fontWeight: FontWeight.w600,
                                    fontSize:   13,
                                  ),
                                ),
                              ]),
                            ));
                          })(),
                        ],
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Revenue Bar Chart ──────────────────────────────────────────────────────

class _RevenueBarChart extends StatelessWidget {
  final Map<String, double> data;
  const _RevenueBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final sorted = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final recent = sorted.length > 14 ? sorted.sublist(sorted.length - 14) : sorted;
    final maxY   = recent.fold<double>(0, (m, e) => e.value > m ? e.value : m);

    return BarChart(BarChartData(
      alignment:    BarChartAlignment.spaceAround,
      maxY:         maxY * 1.25,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => AppTheme.surfaceAlt,
          getTooltipItem:  (group, _, rod, __) => BarTooltipItem(
            Formatters.currency(rod.toY),
            const TextStyle(color: AppTheme.textPrimary, fontSize: 11),
          ),
        ),
      ),
      titlesData: FlTitlesData(
        show:        true,
        topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles:  true,
          reservedSize: 64,
          getTitlesWidget: (v, _) {
            String label;
            if (v >= 1000000) {
              label = '${(v / 1000000).toStringAsFixed(1)}M';
            } else if (v >= 1000) {
              label = '${(v / 1000).toStringAsFixed(0)}K';
            } else {
              label = v.toStringAsFixed(0);
            }
            return Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10));
          },
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles:   true,
          reservedSize: 28,
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            if (idx < 0 || idx >= recent.length) return const SizedBox();
            final parts = recent[idx].key.split('-');
            final label = parts.length == 3 ? '${parts[2]}/${parts[1]}' : recent[idx].key;
            return Transform.rotate(
              angle: -0.4,
              child: Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            );
          },
        )),
      ),
      gridData: FlGridData(
        show:             true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => const FlLine(color: AppTheme.border, strokeWidth: 0.8),
      ),
      borderData: FlBorderData(show: false),
      barGroups: recent.asMap().entries.map((e) => BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY:          e.value.value,
            gradient:     const LinearGradient(
              colors: [AppTheme.accent, AppTheme.accentLight],
              begin:  Alignment.bottomCenter,
              end:    Alignment.topCenter,
            ),
            width:        18,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      )).toList(),
    ));
  }
}

// ── Payment Pie Chart ──────────────────────────────────────────────────────

class _PaymentPieChart extends StatefulWidget {
  final Map<String, double> data;
  const _PaymentPieChart({required this.data});

  @override
  State<_PaymentPieChart> createState() => _PaymentPieChartState();
}

class _PaymentPieChartState extends State<_PaymentPieChart> {
  int? _touchedIndex;

  static const _colors = [AppTheme.accent, AppTheme.info, AppTheme.success, AppTheme.warning];

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();
    final total   = entries.fold<double>(0, (s, e) => s + e.value);

    return Row(children: [
      Expanded(
        child: PieChart(PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (event, resp) {
              setState(() {
                if (event is FlTapUpEvent) {
                  _touchedIndex = resp?.touchedSection?.touchedSectionIndex;
                }
              });
            },
          ),
          sections: entries.asMap().entries.map((e) {
            final isTouched = _touchedIndex == e.key;
            return PieChartSectionData(
              value:     e.value.value,
              color:     _colors[e.key % _colors.length],
              radius:    isTouched ? 85 : 72,
              showTitle: isTouched,
              title:     isTouched
                  ? '${total > 0 ? ((e.value.value / total) * 100).toStringAsFixed(1) : 0}%'
                  : '',
              titleStyle: const TextStyle(
                color:      Colors.white,
                fontSize:   13,
                fontWeight: FontWeight.w700,
              ),
            );
          }).toList(),
          centerSpaceRadius: 45,
          sectionsSpace:     3,
        )),
      ),
      const SizedBox(width: 20),
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.asMap().entries.map((e) => GestureDetector(
          onTap: () => setState(() => _touchedIndex = _touchedIndex == e.key ? null : e.key),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color:        _colors[e.key % _colors.length],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  e.value.key,
                  style: TextStyle(
                    color:      _touchedIndex == e.key ? AppTheme.textPrimary : AppTheme.textSecondary,
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  total > 0
                      ? '${((e.value.value / total) * 100).toStringAsFixed(1)}% · ${Formatters.currency(e.value.value)}'
                      : '0%',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
              ]),
            ]),
          ),
        )).toList(),
      ),
    ]);
  }
}
