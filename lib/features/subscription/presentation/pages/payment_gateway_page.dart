import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../models/subscription.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class PaymentGatewayPage extends ConsumerStatefulWidget {
  final String method; // 'qris' or 'va'
  final PlanType plan;
  final VoidCallback onBack;

  const PaymentGatewayPage(
      {super.key,
      required this.method,
      required this.plan,
      required this.onBack});

  @override
  ConsumerState<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends ConsumerState<PaymentGatewayPage> {
  int _stage = 0;

  @override
  Widget build(BuildContext context) {
    final amount =
        widget.plan == PlanType.yearly ? 'Rp 1.000.000' : 'Rp 100.000';
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(authStateProvider).value;

    return Container(
      color: AppTheme.bg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            _buildSteps(),
            const SizedBox(height: 32),

            // ── Account & Business Summary ──────────────────────────
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.business_rounded,
                          size: 16, color: AppTheme.accent),
                      SizedBox(width: 8),
                      Text(
                        'RINGKASAN AKUN & BISNIS',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _summaryRow(
                      'Nama Bisnis',
                      settings.businessName.isEmpty
                          ? 'Belum Diatur'
                          : settings.businessName),
                  _summaryRow('Email Akun', user?.email ?? '-'),
                  _summaryRow('Paket', widget.plan.displayName),
                  _summaryRow(
                      'Metode',
                      widget.method == 'qris'
                          ? 'QRIS (Gopay/OVO/Dana)'
                          : 'Virtual Account'),
                  _summaryRow(
                      'Durasi',
                      widget.plan == PlanType.yearly
                          ? '1 Tahun (365 Hari)'
                          : '1 Bulan (30 Hari)'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            AppCard(
              child: Column(
                children: [
                  if (_stage == 0) ...[
                    const Text('TOTAL TAGIHAN',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    Text(amount,
                        style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accent)),
                    const Divider(height: 32),
                    const Icon(Icons.receipt_long_rounded,
                        color: AppTheme.accent, size: 48),
                    const SizedBox(height: 16),
                    const Text('Ringkasan Pembayaran',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Ini adalah simulasi alur pembayaran. Tidak ada invoice atau transaksi nyata yang dibuat.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ] else if (_stage == 1) ...[
                    const Text('INSTRUKSI PEMBAYARAN DEMO',
                        style:
                            TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    const SizedBox(height: 20),
                    if (widget.method == 'qris')
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2_rounded,
                                size: 112, color: Colors.black87),
                            Text('QRIS SIMULASI',
                                style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11)),
                          ],
                        ),
                      )
                    else
                      Column(
                        children: [
                          const Icon(Icons.account_balance_rounded,
                              color: AppTheme.accent, size: 48),
                          const SizedBox(height: 12),
                          const Text('Virtual Account Demo',
                              style: TextStyle(color: AppTheme.textMuted)),
                          const SizedBox(height: 6),
                          SelectableText(
                            '8808 1234 5678 9000',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Text('Nominal simulasi: $amount',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Kode dan instruksi ini hanya contoh untuk mencoba user journey.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ] else ...[
                    const Icon(Icons.check_circle_outline_rounded,
                        color: AppTheme.success, size: 56),
                    const SizedBox(height: 16),
                    const Text('Simulasi Pembayaran Selesai',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 8),
                    const Text(
                      'Tidak ada pembayaran nyata dan status langganan belum diubah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                  ],
                  const SizedBox(height: 28),
                  if (_stage < 2)
                    ElevatedButton(
                      onPressed: () => setState(() => _stage++),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        _stage == 0
                            ? 'TAMPILKAN INSTRUKSI'
                            : 'SIMULASIKAN SUDAH MEMBAYAR',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: widget.onBack,
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56)),
                      child: const Text('KEMBALI KE LANGGANAN'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed:
                  _stage == 0 ? widget.onBack : () => setState(() => _stage--),
              child: Text(_stage == 0 ? 'KEMBALI' : 'LANGKAH SEBELUMNYA',
                  style: const TextStyle(color: AppTheme.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    return Row(
      children: [
        _stepCircle('1', 'Metode', true),
        _stepLine(_stage >= 0),
        _stepCircle('2', 'Instruksi', _stage >= 1),
        _stepLine(_stage >= 2),
        _stepCircle('3', 'Selesai', _stage >= 2),
      ],
    );
  }

  Widget _stepCircle(String num, String label, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: active ? AppTheme.accent : AppTheme.border,
          child: Text(num,
              style: TextStyle(
                  color: active ? Colors.white : AppTheme.textMuted,
                  fontSize: 12)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: active ? AppTheme.accent : AppTheme.textMuted)),
      ],
    );
  }

  Widget _stepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 16),
        color: active ? AppTheme.accent : AppTheme.border,
      ),
    );
  }
}
