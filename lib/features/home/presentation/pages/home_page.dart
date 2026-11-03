import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/ads/providers/ads_provider.dart';
import '../../../../core/ads/services/ad_units.dart';
import '../../../../core/config/app_contacts.dart';
import '../../../../core/localization/localization_provider.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/trusted_time_helper.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../../auth/providers/active_cashier_provider.dart';
import '../../../payment/providers/transaction_provider.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../subscription/config/entitlement_config.dart';
import '../../../subscription/models/entitlement.dart';
import '../../../subscription/presentation/pages/subscription_page.dart';
import '../../../subscription/providers/subscription_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBannerIfNeeded();
    });
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _loadBannerIfNeeded() {
    final adsEnabled = ref.read(adsEnabledProvider);
    if (!adsEnabled || _bannerAd != null) return;

    final banner = BannerAd(
      adUnitId: AdUnits.bannerHero,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Hero Banner failed to load: $error');
          ad.dispose();
          if (mounted) setState(() => _isBannerLoaded = false);
        },
      ),
    );

    _bannerAd = banner;
    banner.load();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final activeCashier = ref.watch(activeCashierProvider);
    final activeCashierNotifier = ref.read(activeCashierProvider.notifier);
    final entitlement = ref.watch(entitlementProvider);
    final strings = ref.watch(appStringsProvider);
    final adsEnabled = ref.watch(adsEnabledProvider);

    final storeName = settings.businessName.isEmpty ? 'Toko Saya' : settings.businessName;
    final cashierDisplay = activeCashierNotifier.isMultiCashierMode
        ? 'Kasir: ${activeCashier.name}'
        : 'Pemilik Toko (${settings.ownerName.isEmpty ? 'Admin' : settings.ownerName})';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Hero Gradient Header
              _buildHeroHeader(
                context,
                storeName: storeName,
                cashierDisplay: cashierDisplay,
                adsEnabled: adsEnabled,
              ),

              const SizedBox(height: 20),

              // 2. Subscription & Quota Status Card (For Free Accounts)
              _buildSubscriptionQuotaCard(context, entitlement),

              const SizedBox(height: 20),

              // 3. Feature Grid Section
              const Text(
                'Daftar Fitur Toko',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              _buildFeatureGrid(context, entitlement, strings),

              const SizedBox(height: 20),

              // 4. Manual & Template Downloads (If configured)
              if (AppContacts.isConfigured(AppContacts.userManualUrl) ||
                  AppContacts.isConfigured(AppContacts.excelImportTemplateUrl))
                _buildDownloadLinksCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(
    BuildContext context, {
    required String storeName,
    required String cashierDisplay,
    required bool adsEnabled,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.25),
            AppTheme.surfaceAlt,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Datang,',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                    ),
                    Text(
                      storeName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$cashierDisplay · ${Formatters.date(DateTime.now())}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.accent),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/images/logo.png', width: 44, height: 44, fit: BoxFit.cover),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Banner Ad or Fallback Card
          if (adsEnabled && _isBannerLoaded && _bannerAd != null) ...[
            Container(
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AdWidget(ad: _bannerAd!),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Iklan', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                    );
                  },
                  child: const Text(
                    'Hilangkan iklan dengan Premium →',
                    style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Fallback Benefit Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BuildEra POS Pro',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                        ),
                        Text(
                          'Solusi lengkap kelola kasir, stok, piutang, & cetak nota',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                      );
                    },
                    child: const Text('UPGRADE'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubscriptionQuotaCard(BuildContext context, Entitlement entitlement) {
    final subStateAsync = ref.watch(subscriptionStateProvider);
    final txsAsync = ref.watch(transactionsProvider);

    return subStateAsync.maybeWhen(
      data: (sub) {
        final isPremium = entitlement.isPremium;
        final statusText = isPremium ? 'Paket Premium' : 'Mode Gratis';

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isPremium ? Icons.workspace_premium_rounded : Icons.info_outline_rounded,
                      color: isPremium ? Colors.amber : AppTheme.accent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      statusText,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubscriptionPage()),
                        );
                      },
                      child: Text(isPremium ? 'KELOLA' : 'UPGRADE'),
                    ),
                  ],
                ),
                if (!isPremium) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  txsAsync.maybeWhen(
                    data: (txs) {
                      final countToday = txs.where((t) {
                        final tJakarta = t.createdAt.toUtc().add(const Duration(hours: 7));
                        return TrustedTimeHelper.isSameJakartaDay(tJakarta, TrustedTimeHelper.nowJakarta());
                      }).length;

                      final maxDaily = EntitlementConfig.freeMaxTransactionsPerDay;
                      final remaining = (maxDaily - countToday).clamp(0, maxDaily);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Quota Transaksi Hari Ini:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                              Text('$countToday / $maxDaily terpakai (Sisa: $remaining)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: (countToday / maxDaily).clamp(0.0, 1.0),
                            backgroundColor: AppTheme.surfaceAlt,
                            color: remaining <= 3 ? AppTheme.warning : AppTheme.accent,
                          ),
                        ],
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildFeatureGrid(BuildContext context, Entitlement entitlement, dynamic strings) {
    final nav = ref.read(navigationIndexProvider.notifier);

    final List<({String title, IconData icon, int pageIndex, bool isLocked})> features = [
      (title: 'Kasir POS', icon: Icons.point_of_sale_rounded, pageIndex: AppPageIndices.cashier, isLocked: false),
      (title: 'Produk & Stok', icon: Icons.inventory_2_rounded, pageIndex: AppPageIndices.products, isLocked: false),
      (title: 'Transaksi', icon: Icons.receipt_long_rounded, pageIndex: AppPageIndices.transactions, isLocked: false),
      (title: 'Piutang', icon: Icons.account_balance_wallet_rounded, pageIndex: AppPageIndices.debts, isLocked: false),
      (title: 'Pelanggan', icon: Icons.people_rounded, pageIndex: AppPageIndices.customers, isLocked: false),
      (title: 'Pembelian', icon: Icons.local_shipping_rounded, pageIndex: AppPageIndices.purchase, isLocked: !entitlement.isFeatureUnlocked(PremiumFeature.restock)),
      (title: 'Analitik', icon: Icons.bar_chart_rounded, pageIndex: AppPageIndices.analytics, isLocked: !entitlement.isFeatureUnlocked(PremiumFeature.analytics)),
      (title: 'Barcode', icon: Icons.qr_code_2_rounded, pageIndex: AppPageIndices.barcodes, isLocked: false),
      (title: 'Tagihan', icon: Icons.receipt_rounded, pageIndex: AppPageIndices.bills, isLocked: false),
      (title: 'Tampilan Layar', icon: Icons.display_settings_rounded, pageIndex: AppPageIndices.customerDisplay, isLocked: false),
      (title: 'Pengaturan', icon: Icons.settings_rounded, pageIndex: AppPageIndices.settings, isLocked: false),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: features.length,
      itemBuilder: (context, i) {
        final f = features[i];
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () {
              nav.setIndex(f.pageIndex);
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    children: [
                      Icon(f.icon, size: 28, color: f.isLocked ? AppTheme.textMuted : AppTheme.accent),
                      if (f.isLocked)
                        const Positioned(
                          right: 0,
                          bottom: 0,
                          child: Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    f.title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: f.isLocked ? AppTheme.textMuted : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDownloadLinksCard(BuildContext context) {
    Future<void> openExternal(String url, String label) async {
      final uri = Uri.tryParse(url);
      if (uri == null) {
        showError(context, 'Link $label tidak valid.');
        return;
      }
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
        showError(context, 'Tidak dapat membuka $label saat ini.');
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Panduan & Template',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (AppContacts.isConfigured(AppContacts.userManualUrl))
                  OutlinedButton.icon(
                    onPressed: () => openExternal(AppContacts.userManualUrl, 'Buku Panduan'),
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text('Buku Panduan PDF', style: TextStyle(fontSize: 12)),
                  ),
                if (AppContacts.isConfigured(AppContacts.excelImportTemplateUrl))
                  OutlinedButton.icon(
                    onPressed: () => openExternal(AppContacts.excelImportTemplateUrl, 'Template Excel'),
                    icon: const Icon(Icons.table_chart_rounded, size: 16),
                    label: const Text('Template Excel XLSX', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
