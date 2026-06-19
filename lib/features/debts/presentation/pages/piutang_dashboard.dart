import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../pages/customer_debt_detail_page.dart';
import '../pages/customer_management_page.dart';
import '../../providers/debt_repository.dart';
import '../../utils/debt_report_helper.dart';
import '../../models/customer.dart';
import '../../models/debt.dart';

class PiutangDashboard extends ConsumerWidget {
  const PiutangDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final debtsAsync = ref.watch(debtsProvider(null));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          // Header
          PageHeader(
            title: 'Dashboard Piutang',
            subtitle: 'Kelola dan pantau saldo piutang pelanggan',
            icon: Icons.account_balance_wallet_rounded,
            actions: [
              OutlinedButton.icon(
                onPressed: () => _exportAllOutstanding(ref),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Export Excel'),
              ),
              OutlinedButton.icon(
                onPressed: () => _navigateToCustomerManagement(context),
                icon: const Icon(Icons.people_rounded, size: 18),
                label: const Text('Kelola Pelanggan'),
              ),
            ],
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── KPI Stats ──────────────────────────────────────────
                  _buildSummaryRow(customersAsync, debtsAsync),
                  const SizedBox(height: 32),

                  // ── Customers with Debt ─────────────────────────────────
                  Row(
                    children: [
                      Text('Saldo Piutang per Pelanggan', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCustomerDebtList(context, customersAsync),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(AsyncValue<List<Customer>> customers, AsyncValue<List<Debt>> debts) {
    return customers.when(
      loading: () => const SizedBox(height: 100),
      error:   (_, __) => const SizedBox(),
      data: (custList) {
        final withDebt = custList.where((c) => c.totalOutstanding > 0).toList();
        final totalOut = custList.fold<double>(0, (s, c) => s + c.totalOutstanding);
        
        return debts.when(
          loading: () => const SizedBox(),
          error:   (_, __) => const SizedBox(),
          data: (debtList) {
            final overdueAmount = debtList.where((d) => d.isOverdue).fold<double>(0, (s, d) => s + d.remainingBalance);
            
            return Row(
              children: [
                Expanded(child: StatCard(
                  label: 'Total Piutang Aktif',
                  value: Formatters.currency(totalOut),
                  icon: Icons.account_balance_wallet_rounded,
                )),
                const SizedBox(width: 16),
                Expanded(child: StatCard(
                  label: 'Piutang Menunggak',
                  value: Formatters.currency(overdueAmount),
                  icon: Icons.warning_amber_rounded,
                  accentColor: AppTheme.danger,
                )),
                const SizedBox(width: 16),
                Expanded(child: StatCard(
                  label: 'Pelanggan Berhutang',
                  value: withDebt.length.toString(),
                  icon: Icons.people_rounded,
                  accentColor: AppTheme.info,
                )),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerDebtList(BuildContext context, AsyncValue<List<Customer>> customers) {
    return customers.when(
      loading: () => const AppLoading(),
      error:   (e, _) => Text('Error: $e'),
      data: (custList) {
        final withDebt = custList.where((c) => c.totalOutstanding > 0).toList()
          ..sort((a, b) => b.totalOutstanding.compareTo(a.totalOutstanding));

        if (withDebt.isEmpty) {
          return const EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Tidak ada piutang aktif',
            subtitle: 'Semua pelanggan telah melunasi kewajiban mereka',
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: withDebt.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = withDebt[i];
            return InkWell(
              onTap: () => _navigateToCustomerDetail(context, c),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: AppTheme.bg, shape: BoxShape.circle),
                      child: const Icon(Icons.person_rounded, size: 20, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: Theme.of(context).textTheme.titleMedium),
                          Text(c.phone, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Sisa Saldo', style: Theme.of(context).textTheme.bodySmall),
                        Text(
                          Formatters.currency(c.totalOutstanding),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.warning, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _navigateToCustomerManagement(BuildContext context) {
    // This assumes MainShell uses IndexStack. 
    // Usually we'd use Navigator, but the instructions implied pages inside MainShell.
    // However, for deep management we can just push a full page.
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerManagementPage()));
  }

  void _navigateToCustomerDetail(BuildContext context, Customer customer) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDebtDetailPage(customer: customer)));
  }

  Future<void> _exportAllOutstanding(WidgetRef ref) async {
    final customers = ref.read(customersProvider).asData?.value ?? [];
    if (customers.isEmpty) return;
    await DebtReportHelper.exportOutstandingToExcel(customers);
  }
}
