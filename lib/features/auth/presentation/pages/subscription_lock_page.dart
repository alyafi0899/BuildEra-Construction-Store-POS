import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionLockPage extends ConsumerWidget {
  const SubscriptionLockPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(32),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_rounded, size: 80, color: AppTheme.warning),
                const SizedBox(height: 24),
                Text(
                  'Aktivasi Diperlukan',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Akses ke sistem POS BuildEra saat ini terkunci. Silakan aktifkan langganan Anda untuk melanjutkan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),
                StatCard(
                  label: 'Status Saat Ini',
                  value: settings.subscriptionStatus.toUpperCase(),
                  icon: Icons.info_outline,
                  accentColor: settings.subscriptionStatus == 'active' ? AppTheme.success : AppTheme.danger,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => _handlePayment(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('AKTIFKAN SEKARANG - RP 100.000', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.read(authRepositoryProvider).logout(),
                  child: const Text('Keluar dari Akun', style: TextStyle(color: AppTheme.danger)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePayment(BuildContext context, WidgetRef ref) async {
    final supabase = ref.read(supabaseClientProvider);
    final user = ref.read(authStateProvider).value;
    
    if (user == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menyiapkan pembayaran Xendit...'))
      );

      final response = await supabase.functions.invoke('create-xendit-invoice', body: {
        'userId': user.uid,
        'email': user.email,
        'amount': 100000,
      });

      if (response.status == 200) {
        final invoiceUrl = response.data['invoice_url'];
        if (invoiceUrl != null) {
          final uri = Uri.parse(invoiceUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      } else {
        throw 'Gagal membuat invoice: ${response.status}';
      }
    } catch (e) {
      if (context.mounted) {
        showError(context, 'Terjadi kesalahan: $e');
      }
    }
  }
}
