import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../../features/subscription/providers/bonus_quota_provider.dart';
import '../../../../features/subscription/presentation/pages/subscription_page.dart';
import '../../providers/ads_provider.dart';
import '../../services/ad_units.dart';

class RewardAdDialog extends ConsumerStatefulWidget {
  const RewardAdDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const RewardAdDialog(),
    );
  }

  @override
  ConsumerState<RewardAdDialog> createState() => _RewardAdDialogState();
}

class _RewardAdDialogState extends ConsumerState<RewardAdDialog> {
  bool _isLoadingAd = false;
  String? _statusText;

  Future<void> _watchAd() async {
    final adsEnabled = ref.read(adsEnabledProvider);
    final isSupported = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

    if (!adsEnabled || !isSupported) {
      // Test / Fake Ads fallback: grant reward directly
      final granted = await ref.read(bonusQuotaProvider.notifier).grantRewardBonus();
      if (mounted) {
        if (granted) {
          showSuccess(context, 'Bonus +10 transaksi berhasil ditambahkan (6 jam)');
          Navigator.pop(context, true);
        } else {
          showError(context, 'Batas reward harian telah tercapai');
          Navigator.pop(context, false);
        }
      }
      return;
    }

    setState(() {
      _isLoadingAd = true;
      _statusText = 'Memuat iklan...';
    });

    try {
      RewardedInterstitialAd.load(
        adUnitId: AdUnits.rewardedFeatures,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }

            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                if (mounted) {
                  setState(() => _isLoadingAd = false);
                  showError(context, 'Gagal menampilkan iklan. Coba lagi nanti.');
                }
              },
            );

            ad.show(
              onUserEarnedReward: (adWithoutView, reward) async {
                final granted = await ref.read(bonusQuotaProvider.notifier).grantRewardBonus();
                if (mounted) {
                  setState(() => _isLoadingAd = false);
                  if (granted) {
                    showSuccess(context, 'Bonus +10 transaksi berhasil ditambahkan (6 jam)');
                    Navigator.pop(context, true);
                  } else {
                    showError(context, 'Batas reward harian telah tercapai');
                    Navigator.pop(context, false);
                  }
                }
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('RewardedInterstitialAd failed to load: $error');
            if (mounted) {
              setState(() => _isLoadingAd = false);
              showError(context, 'Iklan belum tersedia saat ini. Silakan coba beberapa saat lagi.');
            }
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAd = false);
        showError(context, 'Gagal memuat iklan: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(bonusQuotaProvider);
    final canClaim = ref.read(bonusQuotaProvider.notifier).canClaimReward();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.video_library_rounded, color: AppTheme.accent),
          SizedBox(width: 10),
          Text('Bonus Kuota Transaksi'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tonton iklan singkat untuk mendapatkan tambahan +10 kuota transaksi yang berlaku selama 6 jam.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Manfaat Reward:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accent)),
                  const SizedBox(height: 4),
                  const Text('• +10 Transaksi Tambahan', style: TextStyle(fontSize: 12)),
                  const Text('• Masa Berlaku: 6 Jam sejak iklan selesai', style: TextStyle(fontSize: 12)),
                  Text('• Klaim Hari Ini: ${quota.rewardsClaimedToday} / 3 kali', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            if (quota.isActive) ...[
              const SizedBox(height: 12),
              Text(
                'Bonus +10 aktif sampai ${Formatters.time(quota.expiresAtUtc?.toLocal() ?? DateTime.now())}',
                style: const TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
            if (_statusText != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const AppLoading(),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_statusText!, style: const TextStyle(fontSize: 12))),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoadingAd ? null : () => Navigator.pop(context, false),
          child: const Text('LEWATI'),
        ),
        ElevatedButton.icon(
          onPressed: (_isLoadingAd || !canClaim) ? null : _watchAd,
          icon: const Icon(Icons.play_circle_fill_rounded),
          label: Text(quota.isActive ? 'BONUS AKTIF' : 'TONTON IKLAN'),
        ),
      ],
    );
  }
}

class LimitReachedSheet extends StatelessWidget {
  const LimitReachedSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LimitReachedSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.warning_amber_rounded, size: 48, color: AppTheme.warning),
          const SizedBox(height: 12),
          const Text(
            'Limit Transaksi Hari Ini Tercapai',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Anda telah mencapai batas 10 transaksi gratis hari ini. Pilih opsi di bawah untuk melanjutkan transaksi tanpa kehilangan isi keranjang.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
          ),
          const SizedBox(height: 24),

          // Option 1: Watch Ad
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await RewardAdDialog.show(context);
              },
              icon: const Icon(Icons.play_circle_fill_rounded, color: AppTheme.accent),
              label: const Text('TONTON IKLAN (+10 TRANSAKSI, 6 JAM)'),
            ),
          ),

          const SizedBox(height: 12),

          // Option 2: Upgrade Premium
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('UPGRADE KE PREMIUM (UNLIMITED)'),
            ),
          ),
        ],
      ),
    );
  }
}
