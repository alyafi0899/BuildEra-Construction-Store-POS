import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/core/utils/formatters.dart';
import 'package:buildera/shared/widgets/common_widgets.dart';
import 'package:buildera/features/debts/providers/debt_repository.dart';
import 'package:buildera/features/debts/models/debt.dart';
import 'customer_debt_detail_page.dart';

class PiutangDashboard extends ConsumerStatefulWidget {
  const PiutangDashboard({super.key});

  @override
  ConsumerState<PiutangDashboard> createState() => _PiutangDashboardState();
}

class _PiutangDashboardState extends ConsumerState<PiutangDashboard> {
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final debtsAsync = ref.watch(debtsProvider(null));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const PageHeader(
            title: 'Laporan Piutang',
            subtitle: 'Ringkasan tagihan pelanggan belum lunas',
            icon: Icons.account_balance_wallet_rounded,
          ),

          // Stats Overview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: colorScheme.surface,
            child: debtsAsync.when(
              data: (list) {
                final totalDebt = list.fold<double>(0, (sum, d) => sum + d.remainingBalance);
                final overdueCount = list.where((d) => d.isOverdue).length;
                return Row(
                  children: [
                    Expanded(child: StatCard(label: 'Total Piutang Aktif', value: Formatters.currency(totalDebt), icon: Icons.payments_rounded, accentColor: colorScheme.primary)),
                    const SizedBox(width: 16),
                    Expanded(child: StatCard(label: 'Nota Jatuh Tempo', value: overdueCount.toString(), icon: Icons.timer_rounded, accentColor: colorScheme.error)),
                  ],
                );
              },
              loading: () => const SizedBox(height: 100),
              error: (_, __) => const SizedBox(),
            ),
          ),

          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.outline)),
            ),
            child: Row(children: [
              SizedBox(
                width: 400,
                child: AppSearchField(
                  controller: _searchCtrl,
                  hintText: 'Cari pelanggan atau no invoice...',
                  onChanged: (v) => setState(() => _search = v),
                  onClear: () => setState(() {
                    _search = '';
                    _searchCtrl.clear();
                  }),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => ref.refresh(debtsProvider(null)),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Refresh'),
              ),
            ]),
          ),

          // Debt List
          Expanded(
            child: debtsAsync.when(
              loading: () => const AppLoading(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                final filtered = list.where((d) => 
                  d.customerName.toLowerCase().contains(_search.toLowerCase()) || 
                  d.invoiceNumber.toLowerCase().contains(_search.toLowerCase())
                ).toList();

                if (filtered.isEmpty) {
                  return const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'Tidak ada piutang aktif');
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _DebtRow(debt: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtRow extends ConsumerWidget {
  final Debt debt;
  const _DebtRow({required this.debt});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOverdue = debt.isOverdue;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () async {
            // Find customer object to navigate to detail
            final customers = ref.read(customersProvider).asData?.value ?? [];
            final customer = customers.firstWhereOrNull((c) => c.id == debt.customerId);
            if (customer != null) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CustomerDebtDetailPage(customer: customer),
              ));
            } else {
              showError(context, 'Data pelanggan tidak ditemukan');
            }
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: colorScheme.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.description_rounded, color: colorScheme.primary, size: 20),
          ),
          title: Row(
            children: [
              Text(debt.customerName, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('•', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.3))),
              const SizedBox(width: 8),
              Text(debt.invoiceNumber, style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text('Jatuh Tempo: ${Formatters.date(debt.dueDate)}', 
                  style: TextStyle(fontSize: 12, color: isOverdue ? colorScheme.error : colorScheme.onSurface.withValues(alpha: 0.6))),
                if (isOverdue) ...[
                  const SizedBox(width: 8),
                  StatusChip(label: 'JATUH TEMPO', color: colorScheme.error),
                ],
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Formatters.currency(debt.remainingBalance), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: colorScheme.primary)),
              Text('SISA TAGIHAN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: colorScheme.onSurface.withValues(alpha: 0.4), letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }
}
