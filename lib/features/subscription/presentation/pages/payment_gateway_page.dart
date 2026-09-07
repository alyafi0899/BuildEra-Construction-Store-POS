import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../providers/subscription_provider.dart';
import '../../models/subscription.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../auth/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentGatewayPage extends ConsumerStatefulWidget {
  final String method; // 'qris' or 'va'
  final PlanType plan;
  final VoidCallback onBack;

  const PaymentGatewayPage({super.key, required this.method, required this.plan, required this.onBack});

  @override
  ConsumerState<PaymentGatewayPage> createState() => _PaymentGatewayPageState();
}

class _PaymentGatewayPageState extends ConsumerState<PaymentGatewayPage> {
  bool _isProcessing = false;

  Future<void> _initiatePayment() async {
    setState(() => _isProcessing = true);
    
    try {
      final invoiceUrl = await ref.read(subscriptionStateProvider.notifier).initiateRealPayment(
        widget.plan, 
        method: widget.method,
      );
      
      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (invoiceUrl != null) {
        final uri = Uri.parse(invoiceUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
        
        if (mounted) {
          widget.onBack(); 
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = widget.plan == PlanType.yearly ? 'Rp 1.000.000' : 'Rp 100.000';
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
                      Icon(Icons.business_rounded, size: 16, color: AppTheme.accent),
                      SizedBox(width: 8),
                      Text('RINGKASAN AKUN & BISNIS', 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _summaryRow('Nama Bisnis', settings.businessName.isEmpty ? 'Belum Diatur' : settings.businessName),
                  _summaryRow('Email Akun', user?.email ?? '-'),
                  _summaryRow('Paket', widget.plan.displayName),
                  _summaryRow('Metode', widget.method == 'qris' ? 'QRIS (Gopay/OVO/Dana)' : 'Virtual Account'),
                  _summaryRow('Durasi', widget.plan == PlanType.yearly ? '1 Tahun (365 Hari)' : '1 Bulan (30 Hari)'),
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
                  
                  const Icon(Icons.security_rounded, color: AppTheme.success, size: 48),
                  const SizedBox(height: 16),
                  const Text('Pembayaran Aman via Xendit', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Text('Anda akan diarahkan ke halaman pembayaran Xendit yang aman untuk menyelesaikan transaksi.', 
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  if (_isProcessing)
                    const Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Sedang menyiapkan invoice...', style: TextStyle(fontStyle: FontStyle.italic)),
                      ],
                    )
                  else
                    ElevatedButton(
                      onPressed: _initiatePayment,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 56),
                        backgroundColor: AppTheme.accent,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('LANJUTKAN KE PEMBAYARAN', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: widget.onBack,
              child: const Text('KEMBALI', style: TextStyle(color: AppTheme.textMuted)),
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
        _stepCircle('2', 'Konfirmasi', true),
        _stepLine(false),
        _stepCircle('3', 'Bayar', false),
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
}
