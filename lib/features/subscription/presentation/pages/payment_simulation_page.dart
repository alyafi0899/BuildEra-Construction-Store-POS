import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/subscription_provider.dart';
import '../../models/subscription.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import 'dart:async';

class PaymentSimulationPage extends ConsumerStatefulWidget {
  final String method; // 'qris' or 'va'
  final PlanType plan;

  const PaymentSimulationPage({super.key, required this.method, required this.plan});

  @override
  ConsumerState<PaymentSimulationPage> createState() => _PaymentSimulationPageState();
}

class _PaymentSimulationPageState extends ConsumerState<PaymentSimulationPage> {
  bool _isVerifying = false;
  bool _isSuccess = false;

  void _simulateVerification() {
    setState(() => _isVerifying = true);
    
    // Simulate Xendit Webhook / Network delay
    Timer(const Duration(seconds: 3), () async {
      await ref.read(subscriptionStateProvider.notifier).confirmDummyPayment(widget.plan);
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _isSuccess = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isSuccess) return _buildSuccessUI();

    final amount = widget.plan == PlanType.yearly ? 'Rp 1.000.000' : 'Rp 100.000';
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('PEMBAYARAN'),
        backgroundColor: AppTheme.surface,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
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
                          Icon(Icons.business_rounded, size: 16, color: AppTheme.accent),
                          SizedBox(width: 8),
                          Text('RINGKASAN AKUN & BISNIS', 
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _summaryRow('Nama Bisnis', settings.businessName),
                      _summaryRow('Email Akun', user?.email ?? '-'),
                      _summaryRow('Paket', widget.plan.displayName),
                      _summaryRow('Metode', widget.method == 'qris' ? 'QRIS (Gopay/OVO/Dana)' : 'Virtual Account BCA'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                AppCard(
                  child: Column(
                    children: [
                      const Text('TOTAL TAGIHAN', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      Text(amount, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                      const Divider(height: 32),
                      if (widget.method == 'qris') _buildQRISUI() else _buildVAUI(),
                      const SizedBox(height: 24),
                      if (_isVerifying)
                        const Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Menunggu konfirmasi pembayaran...', style: TextStyle(fontStyle: FontStyle.italic)),
                          ],
                        )
                      else
                        ElevatedButton(
                          onPressed: _simulateVerification,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 56),
                            backgroundColor: AppTheme.success,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('SAYA SUDAH BAYAR', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {
                    ref.read(subscriptionStateProvider.notifier).cancelPending();
                    Navigator.pop(context);
                  },
                  child: const Text('BATALKAN PEMBAYARAN', style: TextStyle(color: AppTheme.danger)),
                ),
              ],
            ),
          ),
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
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSteps() {
    return Row(
      children: [
        _stepCircle('1', 'Metode', true),
        _stepLine(true),
        _stepCircle('2', 'Bayar', true),
        _stepLine(false),
        _stepCircle('3', 'Selesai', false),
      ],
    );
  }

  Widget _stepCircle(String num, String label, bool active) {
    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: active ? AppTheme.accent : AppTheme.border,
          child: Text(num, style: TextStyle(color: active ? Colors.white : AppTheme.textMuted, fontSize: 12)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: active ? AppTheme.accent : AppTheme.textMuted)),
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

  Widget _buildQRISUI() {
    return Column(
      children: [
        const Text('SCAN QRIS', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppTheme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(Icons.qr_code_2_rounded, size: 150, color: Colors.black87),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Dapat discan dengan Dana, OVO, GoPay, LinkAja, atau Mobile Banking.', 
          textAlign: TextAlign.center, 
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildVAUI() {
    return Column(
      children: [
        const Text('VIRTUAL ACCOUNT BCA', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppTheme.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SelectableText('8877 0812 3456 7890', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: () {}, icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.accent)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text('Masukkan nomor di atas pada menu Transfer Virtual Account bank Anda.', 
          textAlign: TextAlign.center, 
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildSuccessUI() {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, size: 100, color: AppTheme.success),
            const SizedBox(height: 24),
            const Text('Pembayaran Berhasil!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Akun Anda telah ditingkatkan ke Full Features.', style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
              child: const Text('KEMBALI KE DASHBOARD'),
            ),
          ],
        ),
      ),
    );
  }
}
