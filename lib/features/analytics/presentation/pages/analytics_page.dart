import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../payment/providers/transaction_provider.dart';
import '../../../../shared/models/transaction.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../core/utils/report_helper.dart';
import '../../../inventory/models/restock_record.dart';
import '../../../inventory/providers/restock_provider.dart';
import '../../../products/providers/product_provider.dart';
import '../../../../shared/models/product.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _downloadReport(WidgetRef ref, List<Transaction> allTxs, List<Product> allProducts, List<RestockRecord> allRestocks, String type) async {
    final now = DateTime.now();
    List<Transaction> filtered = [];
    String periodName = '';

    switch (type) {
      case 'daily':
        filtered = allTxs.where((t) => 
          t.createdAt.year == now.year && 
          t.createdAt.month == now.month && 
          t.createdAt.day == now.day).toList();
        periodName = 'Hari Ini (${Formatters.date(now)})';
        break;
      case 'weekly':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        filtered = allTxs.where((t) => t.createdAt.isAfter(start) || t.createdAt.isAtSameMomentAs(start)).toList();
        periodName = 'Minggu Ini';
        break;
      case 'monthly':
        filtered = allTxs.where((t) => 
          t.createdAt.year == now.year && 
          t.createdAt.month == now.month).toList();
        periodName = 'Bulan Ini (${Formatters.month(now.month)} ${now.year})';
        break;
      case 'yearly':
        filtered = allTxs.where((t) => t.createdAt.year == now.year).toList();
        periodName = 'Tahun Ini (${now.year})';
        break;
      case 'all':
        filtered = allTxs;
        periodName = 'Semua Data';
        break;
    }

    if (filtered.isEmpty) {
      if (mounted) showError(context, 'Tidak ada data transaksi untuk periode ini');
      return;
    }

    final settings = ref.read(settingsProvider);
    await ReportHelper.generateAndDownloadReport(
      transactions: filtered, 
      products: allProducts,
      restocks: allRestocks,
      periodName: periodName, 
      settings: settings
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final summaryAsync = ref.watch(salesSummaryProvider);
        final transactionsAsync = ref.watch(transactionsProvider);
        final productsAsync = ref.watch(productsProvider);
        final restocksAsync = ref.watch(restockHistoryProvider);

        return Scaffold(
          backgroundColor: AppTheme.bg,
          body: Column(
            children: [
              // Header
              PageHeader(
              title: 'Analitik Penjualan',
              subtitle: 'Ringkasan performa toko secara keseluruhan',
              icon: Icons.bar_chart_rounded,
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
                      onPressed: null, // Let popup handle it
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download Laporan'),
                      style: OutlinedButton.styleFrom(
                        disabledForegroundColor: AppTheme.accent,
                        side: const BorderSide(color: AppTheme.accent),
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
                OutlinedButton.icon(
                  onPressed: () => ref.refresh(salesSummaryProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),

            Expanded(
              child: summaryAsync.when(
                loading: () => const AppLoading(),
                error:   (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.danger))),
                data: (summary) => Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Profit & Performance Cards ───────────────────────
                        Row(children: [
                          Expanded(child: StatCard(
                            label:   'Net Profit Hari Ini',
                            value:   Formatters.currency(summary.todayNetProfit),
                            icon:    Icons.today_rounded,
                            accentColor: AppTheme.success,
                            subtitle: 'Dari ${Formatters.currency(summary.todayRevenue)} omzet',
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: StatCard(
                            label:   'Net Profit Bulan Ini',
                            value:   Formatters.currency(summary.monthlyNetProfit),
                            icon:    Icons.calendar_month_rounded,
                            accentColor: AppTheme.success,
                            subtitle: 'Dari ${Formatters.currency(summary.monthlyRevenue)} omzet',
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: StatCard(
                            label:   'Potensi Profit Stok',
                            value:   Formatters.currency(summary.potentialInventoryProfit),
                            icon:    Icons.inventory_2_rounded,
                            accentColor: AppTheme.info,
                            subtitle: 'Jika stok sisa terjual',
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: StatCard(
                            label:       'Maksimum Profit',
                            value:       Formatters.currency(summary.maxInventoryProfit),
                            icon:        Icons.auto_graph_rounded,
                            accentColor: AppTheme.warning,
                            subtitle:    'Total Estimasi Profit',
                          )),
                        ]),
                        const SizedBox(height: 24),

                        // ── Payment Reminders ─────────────────────────────────
                        if (summary.unpaidSupplierProducts > 0 || summary.unpaidShippingProducts > 0) ...[
                          _PaymentReminders(
                            unpaidSupplier: summary.unpaidSupplierDetails,
                            unpaidShipping: summary.unpaidShippingDetails,
                          ),
                          const SizedBox(height: 24),
                        ],

                        // ── KPI Row (Total) ───────────────────────────────────
                        Row(children: [
                          Expanded(child: StatCard(
                            label:   'Total Pendapatan',
                            value:   Formatters.currency(summary.totalRevenue),
                            icon:    Icons.attach_money_rounded,
                            subtitle: 'Seluruh Transaksi',
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: StatCard(
                            label:   'Total Laba Bersih',
                            value:   Formatters.currency(summary.totalNetProfit),
                            icon:    Icons.trending_up_rounded,
                            accentColor: AppTheme.success,
                            subtitle: 'Seluruh Transaksi',
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: StatCard(
                            label:   'Rata-rata Order',
                            value:   Formatters.currency(summary.avgOrderValue),
                            icon:    Icons.shopping_bag_rounded,
                            accentColor: AppTheme.accentLight,
                            subtitle: 'Per Transaksi',
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: StatCard(
                            label:       'Produk Terdaftar',
                            value:       summary.topProducts.length.toString(),
                            icon:        Icons.inventory_2_rounded,
                            accentColor: AppTheme.warning,
                            subtitle:    'Total SKU',
                          )),
                        ]),
                        const SizedBox(height: 24),

                        // ── Charts Row ─────────────────────────────────────────
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                              ...summary.topProducts.take(10).toList().asMap().entries.map((entry) {
                                final rank = entry.key + 1;
                                final prod = entry.value;
                                final maxRev = summary.topProducts.first.revenue;
                                final ratio = maxRev > 0 ? prod.revenue / maxRev : 0.0;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(children: [
                                    SizedBox(
                                      width: 32,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: rank <= 3
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
                                  Expanded(flex: 2, child: Text('Laba Bersih', textAlign: TextAlign.right, style: _tableHeaderStyle)),
                                  const SizedBox(width: 40),
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
      },
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
    return Consumer(builder: (context, ref, _) {
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
              Expanded(flex: 2, child: Text(Formatters.currency(s.netProfit), textAlign: TextAlign.right, style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold))),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () {
                  final settings = ref.read(settingsProvider);
                  final products = ref.read(productsProvider).asData?.value ?? [];
                  final restocks = ref.read(restockHistoryProvider).asData?.value ?? [];
                  ReportHelper.generateAndDownloadReport(
                    transactions: s.transactions, 
                    products: products,
                    restocks: restocks,
                    periodName: 'Hari Ini (${s.date})', 
                    settings: settings
                  );
                },
                icon: const Icon(Icons.download_rounded, size: 18, color: AppTheme.accent),
                tooltip: 'Download Laporan Hari Ini',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 20, color: AppTheme.textMuted),
            ]),
          ),
        ),
        if (_expanded)
          Container(
            margin: const EdgeInsets.only(top: 4, bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        AppTheme.surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border:       Border.all(color: AppTheme.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.receipt_long_rounded, size: 14, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text('RINCIAN TRANSAKSI & PRODUK', 
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1.1,
                    color: AppTheme.accent,
                  )),
              ]),
              const SizedBox(height: 16),
              ...s.transactions.map((t) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(children: [
                      Text(t.invoiceNumber, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 12),
                      StatusChip(label: t.paymentMethod, color: AppTheme.textMuted),
                      const Spacer(),
                      Text('Total: ${Formatters.currency(t.total)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 8, bottom: 20),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, right: 10),
                        child: Row(children: [
                          Expanded(flex: 3, child: _smallTh('Produk')),
                          Expanded(child: _smallTh('Qty', TextAlign.center)),
                          Expanded(flex: 2, child: _smallTh('Modal', TextAlign.right)),
                          Expanded(flex: 2, child: _smallTh('Jual', TextAlign.right)),
                          Expanded(flex: 2, child: _smallTh('Profit', TextAlign.right)),
                        ]),
                      ),
                      const Divider(height: 1, color: AppTheme.border),
                      ...t.items.map((item) {
                        final itemProfit = item.subtotal - (item.costPrice * item.quantity);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            Expanded(flex: 3, child: Text(item.productName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                            Expanded(child: Text('${Formatters.decimal(item.quantity)} ${item.unitName}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))),
                            Expanded(flex: 2, child: Text(Formatters.currency(item.costPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                            Expanded(flex: 2, child: Text(Formatters.currency(item.soldPrice), textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
                            Expanded(flex: 2, child: Text(Formatters.currency(itemProfit), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: itemProfit >= 0 ? AppTheme.success : AppTheme.danger))),
                          ]),
                        );
                      }),
                    ]),
                  ),
                ],
              )),
            ]),
          ),
      ]);
    });
  }

  Widget _smallTh(String label, [TextAlign align = TextAlign.left]) {
    return Text(label, textAlign: align, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted));
  }
}

class _PaymentReminders extends StatelessWidget {
  final List<UnpaidBillDetail> unpaidSupplier;
  final List<UnpaidBillDetail> unpaidShipping;
  const _PaymentReminders({required this.unpaidSupplier, required this.unpaidShipping});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Tagihan Belum Dibayar',
            icon: Icons.notification_important_rounded,
            color: AppTheme.warning,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BillList(
                  title: 'Supplier',
                  icon: Icons.business_rounded,
                  bills: unpaidSupplier,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _BillList(
                  title: 'Ekspedisi',
                  icon: Icons.local_shipping_rounded,
                  bills: unpaidShipping,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BillList extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<UnpaidBillDetail> bills;

  const _BillList({required this.title, required this.icon, required this.bills});

  @override
  Widget build(BuildContext context) {
    if (bills.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
          const SizedBox(width: 8),
          Text('Semua tagihan $title lunas', style: const TextStyle(color: AppTheme.success, fontSize: 12)),
        ]),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppTheme.textSecondary, letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 12),
        ...bills.map((b) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.warning.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.entityName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${b.count} Batch Aktif', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              ])),
              Text(Formatters.currency(b.remainingAmount), style: const TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w900, fontSize: 13)),
            ]),
          ),
        )),
      ],
    );
  }
}

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
