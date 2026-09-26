import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/subscription_provider.dart';
import '../widgets/subscription_agreement_dialog.dart';
import '../../models/subscription.dart';
import '../../../../core/utils/formatters.dart';
import 'package:intl/intl.dart';
import 'payment_gateway_page.dart';

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  bool _isConfirming = false;
  String? _tempMethod;
  PlanType? _tempPlan;

  @override
  Widget build(BuildContext context) {
    final subAsync = ref.watch(subscriptionStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('PAKET LANGGANAN'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      body: subAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $err'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(subscriptionStateProvider.notifier).refresh(),
                child: const Text('COBA LAGI'),
              ),
            ],
          ),
        ),
        data: (sub) {
          if (_isConfirming && _tempMethod != null && _tempPlan != null) {
            return PaymentGatewayPage(
                method: _tempMethod!,
                plan: _tempPlan!,
                onBack: () => setState(() => _isConfirming = false));
          }

          if (sub?.status == SubscriptionStatus.pending) {
            return _buildPendingUI(context, sub!.planType);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sub != null && sub.isNearExpiry) _buildExpiryWarning(sub),
                _buildStatusCard(context, sub),
                const SizedBox(height: 40),
                if (sub?.planType == PlanType.free ||
                    (sub?.expiresAt != null &&
                        sub!.expiresAt!.isBefore(DateTime.now())))
                  PricingSection(
                    onUpgrade: (plan) => _handleUpgrade(context, ref, plan),
                    currentSub: sub,
                  )
                else
                  _buildActivePlanInfo(context, sub!),
                const SizedBox(height: 48),
                const Divider(),
                const SizedBox(height: 32),
                _buildHistorySection(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistorySection() {
    final historyAsync = ref.watch(subscriptionHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.history_rounded,
                size: 20, color: AppTheme.textMuted),
            const SizedBox(width: 12),
            Text(
              'RIWAYAT LANGGANAN',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 1,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 20),
        historyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Text('Gagal memuat riwayat: $err'),
          data: (list) {
            if (list.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceAlt.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('Belum ada riwayat transaksi.',
                      style: TextStyle(
                          color: AppTheme.textMuted,
                          fontStyle: FontStyle.italic)),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final item = list[i];
                return AppCard(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded,
                            color: AppTheme.success, size: 18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Paket ${item.planType.displayName}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14)),
                            Text(
                                'Dibayar via ${item.paymentMethod ?? "Gerbang Pembayaran"}',
                                style: const TextStyle(
                                    color: AppTheme.textMuted, fontSize: 12)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(Formatters.currency(item.amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accent)),
                          Text(DateFormat('dd MMM yyyy').format(item.createdAt),
                              style: const TextStyle(
                                  color: AppTheme.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildExpiryWarning(Subscription sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Peringatan: Masa langganan Anda akan habis dalam ${sub.daysRemaining} hari. Segera perpanjang paket Anda.',
              style: const TextStyle(
                  color: AppTheme.warning, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, dynamic sub) {
    final isPremium = sub?.isPremium ?? false;
    final statusText = isPremium
        ? 'AKTIF'
        : (sub?.status.toString().split('.').last.toUpperCase() ?? 'FREE');
    final color = isPremium ? AppTheme.success : AppTheme.textMuted;

    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
                isPremium ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: color),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPremium
                      ? 'Paket ${sub?.planType.displayName}'
                      : 'Paket Gratis',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isPremium && sub != null)
                  Text(
                    sub.expiresAt == null
                        ? 'Anda telah menggunakan layanan selama ${sub.daysActive} hari. Akses premium aktif tanpa tanggal kedaluwarsa.'
                        : 'Anda telah menggunakan layanan selama ${sub.daysActive} hari. Berlaku hingga: ${DateFormat('dd MMMM yyyy').format(sub.expiresAt!)}',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                  )
                else
                  const Text('Gunakan fitur premium untuk hasil maksimal',
                      style:
                          TextStyle(color: AppTheme.textMuted, fontSize: 13)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              statusText,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivePlanInfo(BuildContext context, Subscription sub) {
    print('DEBUG: Building ActivePlanInfo for plan: ${sub.planType}');
    return Center(
      child: Column(
        children: [
          const Icon(Icons.stars_rounded, size: 80, color: Colors.orange),
          const SizedBox(height: 24),
          Text(
            'Selamat! Akun ${sub.planType.displayName} Aktif',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Anda sedang menikmati seluruh fitur premium POS Construction.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: AppTheme.bg,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(32))),
                builder: (context) => DraggableScrollableSheet(
                  initialChildSize: 0.9,
                  expand: false,
                  builder: (context, scrollController) => SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(32),
                    child: PricingSection(
                      onUpgrade: (plan) {
                        Navigator.pop(context);
                        _handleUpgrade(context, ref, plan);
                      },
                    ),
                  ),
                ),
              );
            },
            child: const Text('UPGRADE / PERPANJANG'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingUI(BuildContext context, PlanType plan) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.hourglass_empty_rounded,
              size: 64, color: AppTheme.accent),
          const SizedBox(height: 24),
          const Text('Menunggu Pembayaran',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
              'Selesaikan pembayaran ${plan.displayName} Anda untuk membuka fitur premium.'),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _showPaymentMethods(context, plan),
            child: const Text('LIHAT INSTRUKSI PEMBAYARAN'),
          ),
        ],
      ),
    );
  }

  void _handleUpgrade(BuildContext context, WidgetRef ref, PlanType plan) {
    showDialog(
      context: context,
      builder: (context) => SubscriptionAgreementDialog(
        plan: plan,
        onAccepted: () {
          Navigator.pop(context); // Close agreement dialog
          _showPaymentMethods(context, plan); // SHOW METHOD SELECTION FIRST
        },
      ),
    );
  }

  void _showPaymentMethods(BuildContext context, PlanType plan) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pilih Metode Pembayaran',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _methodTile(context, Icons.qr_code_scanner_rounded, 'QRIS',
                'Bayar instan via GoPay, OVO, Dana, dll', () {
              Navigator.pop(context);
              setState(() {
                _tempMethod = 'qris';
                _tempPlan = plan;
                _isConfirming = true;
              });
            }),
            const SizedBox(height: 12),
            _methodTile(context, Icons.account_balance_rounded,
                'Virtual Account', 'Transfer via Bank / ATM', () {
              Navigator.pop(context);
              setState(() {
                _tempMethod = 'va';
                _tempPlan = plan;
                _isConfirming = true;
              });
            }),
          ],
        ),
      ),
    );
  }

  Widget _methodTile(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppTheme.accent),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right_rounded),
      shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppTheme.border),
          borderRadius: BorderRadius.circular(12)),
    );
  }
}

class PricingSection extends StatefulWidget {
  final Function(PlanType) onUpgrade;
  final Subscription? currentSub;
  const PricingSection({super.key, required this.onUpgrade, this.currentSub});

  @override
  State<PricingSection> createState() => _PricingSectionState();
}

class _PricingSectionState extends State<PricingSection> {
  bool _isYearly = false;

  @override
  Widget build(BuildContext context) {
    // Lock yearly upgrade if already on yearly plan
    final isAlreadyYearly = widget.currentSub?.planType == PlanType.yearly &&
        widget.currentSub?.isPremium == true;

    return Column(
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _toggleButton('BULANAN', !_isYearly,
                    () => setState(() => _isYearly = false)),
                _toggleButton('TAHUNAN', _isYearly,
                    () => setState(() => _isYearly = true)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Card(
              elevation: 8,
              shadowColor: AppTheme.accent.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
                side: const BorderSide(color: AppTheme.accent, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    if (_isYearly)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: AppTheme.success,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('HEMAT 20%',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    Text(
                      _isYearly ? 'Paket Tahunan' : 'Paket Bulanan',
                      style: const TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Rp',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textSecondary)),
                        const SizedBox(width: 4),
                        Text(_isYearly ? '1.000.000' : '100.000',
                            style: const TextStyle(
                                fontSize: 48, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 4),
                        Text(_isYearly ? '/ tahun' : '/ bulan',
                            style: const TextStyle(color: AppTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 32),
                    _buildFeatureItem('Laporan Analitik & Grafik Lengkap'),
                    _buildFeatureItem('Kelola Stok & Inventori Tanpa Batas'),
                    _buildFeatureItem('Sinkronisasi Multi-Device (Cloud)'),
                    _buildFeatureItem('Struk Kustom dengan Logo Sendiri'),
                    _buildFeatureItem('Support Prioritas & Update Fitur'),
                    const SizedBox(height: 48),
                    if (_isYearly && isAlreadyYearly)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceAlt,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: AppTheme.success, size: 20),
                            SizedBox(width: 12),
                            Text('PAKET TAHUNAN SEDANG AKTIF',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textMuted)),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => widget.onUpgrade(
                            _isYearly ? PlanType.yearly : PlanType.monthly),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 64),
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          elevation: 4,
                        ),
                        child: Text(
                          _isYearly &&
                                  widget.currentSub?.planType ==
                                      PlanType.monthly
                              ? 'UPGRADE KE TAHUNAN'
                              : 'BERLANGGANAN SEKARANG',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1),
                        ),
                      ),
                    const SizedBox(height: 16),
                    const Text(
                      '* Alur pembayaran saat ini berupa simulasi; belum ada transaksi nyata.',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return Material(
      color: active ? AppTheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      elevation: active ? 2 : 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: active ? AppTheme.accent : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.success, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
