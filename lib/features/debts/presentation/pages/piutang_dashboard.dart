import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../pages/customer_debt_detail_page.dart';
import '../../providers/debt_repository.dart';
import '../../utils/debt_report_helper.dart';
import '../../models/customer.dart';
import '../../models/debt.dart';
import '../../../../shared/widgets/security_gate.dart';
import '../../../../core/providers/navigation_provider.dart';

class PiutangDashboard extends ConsumerWidget {
  const PiutangDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersProvider);
    final debtsAsync = ref.watch(debtsProvider(null));

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: PinGate(
        child: Column(
          children: [
          // Header
          PageHeader(
            title: 'Dashboard Piutang',
            subtitle: 'Kelola dan pantau saldo piutang pelanggan',
            icon: Icons.account_balance_wallet_rounded,
            actions: [
              IconButton(
                onPressed: () => ref.read(navigationIndexProvider.notifier).setIndex(0),
                icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textMuted),
                tooltip: 'Kembali ke Kasir',
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _exportAllOutstanding(ref),
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const Text('Export Excel'),
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
    return Consumer(
      builder: (context, ref, child) {
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
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: AppTheme.surfaceAlt,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: InkWell(
                      onTap: () => _navigateToCustomerDetail(context, c),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
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
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 20, color: AppTheme.accent),
                              onPressed: () {
                                _showEditCustomerDialog(context, ref, c);
                              },
                              tooltip: 'Edit Data Pelanggan',
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showEditCustomerDialog(BuildContext context, WidgetRef ref, Customer customer) {
    final nameCtrl = TextEditingController(text: customer.name);
    final phoneCtrl = TextEditingController(text: customer.phone);
    final addrCtrl = TextEditingController(text: customer.address);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Data Pelanggan'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nama Lengkap *', isDense: true),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Nomor HP', isDense: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: addrCtrl,
                decoration: const InputDecoration(labelText: 'Alamat', isDense: true),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final updated = customer.copyWith(
                  name: nameCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  address: addrCtrl.text.trim().isEmpty ? null : addrCtrl.text.trim(),
                );
                await ref.read(debtRepositoryProvider).saveCustomer(updated);
                if (context.mounted) {
                  Navigator.pop(context);
                  showSuccess(context, 'Data pelanggan diperbarui');
                }
              }
            },
            child: const Text('Simpan Perubahan'),
          ),
        ],
      ),
    );
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
