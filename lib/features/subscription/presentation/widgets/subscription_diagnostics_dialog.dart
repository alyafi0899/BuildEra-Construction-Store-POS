import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/trusted_time_helper.dart';
import '../../models/subscription.dart';
import '../../providers/subscription_provider.dart';

class SubscriptionDiagnosticsDialog extends ConsumerStatefulWidget {
  final Subscription? currentSub;

  const SubscriptionDiagnosticsDialog({super.key, this.currentSub});

  @override
  ConsumerState<SubscriptionDiagnosticsDialog> createState() =>
      _SubscriptionDiagnosticsDialogState();
}

class _SubscriptionDiagnosticsDialogState
    extends ConsumerState<SubscriptionDiagnosticsDialog> {
  bool _isRefreshing = false;
  String? _lastRefreshResult;
  DateTime? _lastRefreshTime;

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });

    try {
      await ref.read(subscriptionStateProvider.notifier).refresh();
      await ref.read(entitlementProvider.notifier).syncPlaySubscriptionOnDemand(force: true);
      await ref.read(entitlementProvider.notifier).refresh();
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _lastRefreshTime = DateTime.now();
          _lastRefreshResult = 'Sukses (terverifikasi)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _lastRefreshTime = DateTime.now();
          _lastRefreshResult = 'Gagal: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.currentSub ?? ref.watch(subscriptionStateProvider).value;
    final entitlement = ref.watch(entitlementProvider);
    final nowUtc = TrustedTimeHelper.nowUtc();
    final systemNowUtc = DateTime.now().toUtc();
    final offsetSec = (TrustedTimeHelper.cachedOffsetMs / 1000).toStringAsFixed(1);

    return AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.analytics_rounded, color: AppTheme.accent, size: 24),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Diagnosa Status Langganan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _sectionHeader('DATABASE STATUS (DB)'),
            _diagRow('Status DB', sub?.status.name ?? 'none'),
            _diagRow('Plan Type', '${sub?.planType.displayName ?? 'Gratis'} (${sub?.planType.name ?? 'free'})'),
            _diagRow('Expires At (UTC)', sub?.expiresAt?.toUtc().toIso8601String() ?? 'N/A'),
            _diagRow(
              'Expires At (Lokal)',
              sub?.expiresAt != null
                  ? DateFormat('dd MMM yyyy, HH:mm:ss').format(sub!.expiresAt!.toLocal())
                  : 'N/A',
            ),
            _diagRow(
              'Grace Ends At (UTC)',
              sub?.gracePeriodEndsAt?.toUtc().toIso8601String() ?? 'N/A',
            ),
            _diagRow(
              'Grace Ends At (Lokal)',
              sub?.gracePeriodEndsAt != null
                  ? DateFormat('dd MMM yyyy, HH:mm:ss').format(sub!.gracePeriodEndsAt!.toLocal())
                  : 'N/A',
            ),
            _diagRow('Is Bypassed', '${sub?.isBypassed ?? false}'),
            _diagRow('Last Order ID', sub?.lastExternalId ?? 'N/A'),

            const SizedBox(height: 16),
            _sectionHeader('WAKTU TERPERCAYA (TRUSTED TIME)'),
            _diagRow('Trusted Now (UTC)', nowUtc.toIso8601String()),
            _diagRow('System Now (UTC)', systemNowUtc.toIso8601String()),
            _diagRow('System Offset', '$offsetSec detik'),
            _diagRow('Hasil sub.isPremiumAt', '${sub?.isPremiumAt(nowUtc) ?? false}'),

            const SizedBox(height: 16),
            _sectionHeader('ENTITLEMENT (SINGLE SOURCE)'),
            _diagRow('Is Resolved', '${entitlement.isResolved}'),
            _diagRow('Is Premium', '${entitlement.isPremium}'),
            _diagRow('Entitlement Source', entitlement.source.name),
            _diagRow('Valid Until (UTC)', entitlement.validUntil?.toUtc().toIso8601String() ?? 'N/A'),
            _diagRow(
              'Valid Until (Lokal)',
              entitlement.validUntil != null
                  ? DateFormat('dd MMM yyyy, HH:mm:ss').format(entitlement.validUntil!.toLocal())
                  : 'N/A',
            ),

            const SizedBox(height: 16),
            _sectionHeader('RIWAYAT REFRESH TERAKHIR'),
            _diagRow(
              'Waktu Refresh',
              _lastRefreshTime != null
                  ? DateFormat('HH:mm:ss').format(_lastRefreshTime!)
                  : 'Belum pernah disegarkan',
            ),
            _diagRow('Hasil Refresh', _lastRefreshResult ?? 'Siap'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('TUTUP'),
        ),
        ElevatedButton.icon(
          onPressed: _isRefreshing ? null : _handleRefresh,
          icon: _isRefreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('SEGARKAN SEKARANG'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
