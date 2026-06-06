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
                        subtitle: 'Omzet Gross',
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: StatCard(
                        label:   'Total Laba Kotor',
                        value:   Formatters.currency(summary.totalGrossProfit),
                        icon:    Icons.trending_up_rounded,
                        accentColor: AppTheme.info,
                        subtitle: 'Profit Potensial',
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: StatCard(
                        label:   'Total Laba Bersih',
                        value:   Formatters.currency(summary.totalNetProfit),
                        icon:    Icons.auto_graph_rounded,
                        accentColor: AppTheme.success,
                        subtitle: 'Profit Aktual',
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: StatCard(
                        label:       'Produk Terjual',
                        value:       summary.topProducts.length.toString(),
                        icon:        Icons.inventory_2_rounded,
                        accentColor: AppTheme.warning,
                        subtitle:    'SKU Aktif',
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
                          title: 'Laporan Detail Harian',
                          icon:  Icons.calendar_today_rounded,
                        ),
                        const SizedBox(height: 16),
                        if (summary.dailyDetails.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(child: Text('Belum ada data harian', style: TextStyle(color: AppTheme.textMuted))),
                          )
                        else ...[
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color:        AppTheme.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(children: [
                              Expanded(flex: 2, child: Text('Tanggal', style: _tableHeaderStyle)),
                              Expanded(child: Text('Transaksi', textAlign: TextAlign.center, style: _tableHeaderStyle)),
                              Expanded(flex: 2, child: Text('Pendapatan', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                              Expanded(flex: 2, child: Text('Laba Kotor', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                              Expanded(flex: 2, child: Text('Laba Bersih', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                              const SizedBox(width: 40), // Space for arrow
                            ]),
                          ),
                          const SizedBox(height: 8),
                          ListView.separated(
                            shrinkWrap:  true,
                            physics:     const NeverScrollableScrollPhysics(),
                            itemCount:   summary.dailyDetails.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (_, i) => _DailyExpandableRow(summary: summary.dailyDetails[i]),
                          ),
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

  static const _tableHeaderStyle = TextStyle(
    color:      AppTheme.textSecondary,
    fontSize:   11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
  );
}

class _DailyExpandableRow extends StatefulWidget {
  final DailySummary summary;
  const _DailyExpandableRow({required this.summary});

  @override
  State<_DailyExpandableRow> createState() => _DailyExpandableRowState();
}

class _DailyExpandableRowState extends State<_DailyExpandableRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    return Column(children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color:        _expanded ? AppTheme.accent.withValues(alpha: 0.05) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border:       Border.all(color: _expanded ? AppTheme.accent.withValues(alpha: 0.2) : Colors.transparent),
          ),
          child: Row(children: [
            Expanded(flex: 2, child: Text(s.date, style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(child: Text('${s.transactionCount}', textAlign: TextAlign.center)),
            Expanded(flex: 2, child: Text(Formatters.currency(s.revenue), textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text(Formatters.currency(s.grossProfit), textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.info, fontWeight: FontWeight.bold))),
            Expanded(flex: 2, child: Text(Formatters.currency(s.netProfit), textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8),
            Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: AppTheme.textMuted),
          ]),
        ),
      ),
      if (_expanded)
        Container(
          margin: const EdgeInsets.only(top: 4, bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:        AppTheme.surfaceAlt.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Daftar Transaksi:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            ...s.transactions.map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Text(t.invoiceNumber, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                const SizedBox(width: 12),
                Text(t.paymentMethod, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                const Spacer(),
                Text(Formatters.currency(t.total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            )),
          ]),
        ),
    ]);
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
