import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../features/settings/models/store_settings.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../core/sync/widgets/sync_status_bar.dart';
import '../../core/providers/navigation_provider.dart';
import '../../core/localization/localization_provider.dart';
import '../../core/localization/app_strings.dart';

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  final String? category;
  const _NavItem(this.icon, this.label, this.index, [this.category]);
}

const _navItems = [
  // OPERASIONAL
  _NavItem(Icons.point_of_sale_rounded, 'Kasir', 0, 'OPERASIONAL'),
  _NavItem(Icons.local_shipping_rounded, 'Pembelian', 10, 'OPERASIONAL'),
  _NavItem(Icons.history_edu_rounded, 'Riwayat Beli', 11, 'OPERASIONAL'),
  _NavItem(Icons.receipt_long_rounded, 'Transaksi', 2, 'OPERASIONAL'),
  _NavItem(Icons.account_balance_wallet_rounded, 'Piutang', 3, 'OPERASIONAL'),
  _NavItem(Icons.people_rounded, 'Pelanggan', 4, 'OPERASIONAL'),

  // INVENTORI
  _NavItem(Icons.inventory_2_rounded, 'Produk / Stok', 1, 'INVENTORI'),
  _NavItem(Icons.qr_code_2_rounded, 'Label Barcode', 6, 'INVENTORI'),

  // FINANSIAL
  _NavItem(Icons.bar_chart_rounded, 'Analitik', 5, 'FINANSIAL'),
  _NavItem(Icons.receipt_rounded, 'Tagihan', 8, 'FINANSIAL'),

  // SISTEM
  _NavItem(Icons.settings_rounded, 'Pengaturan', 7, 'SISTEM'),
];

String _getNavItemLabel(_NavItem item, AppStrings strings) {
  switch (item.index) {
    case 0: return strings.navCashier;
    case 1: return strings.navProducts;
    case 2: return strings.navTransactions;
    case 3: return strings.navDebts;
    case 4: return strings.navCustomers;
    case 5: return strings.navAnalytics;
    case 6: return strings.navBarcodes;
    case 7: return strings.navSettings;
    case 8: return strings.navBills;
    case 10: return strings.navPurchases;
    case 11: return strings.navPurchaseHistory;
    default: return item.label;
  }
}

String _getCategoryTitle(String cat, AppStrings strings) {
  if (cat == 'OPERASIONAL') return strings.isEnglish ? 'OPERATIONAL' : 'OPERASIONAL';
  if (cat == 'INVENTORI') return strings.isEnglish ? 'INVENTORY' : 'INVENTORI';
  if (cat == 'FINANSIAL') return strings.isEnglish ? 'FINANCIAL' : 'FINANSIAL';
  if (cat == 'SISTEM') return strings.isEnglish ? 'SYSTEM' : 'SISTEM';
  return cat;
}

class AppSidebar extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool compactMode;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.compactMode = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isCollapsed = compactMode || ref.watch(sidebarCollapsedProvider);
    final businessName = settings.businessName.isEmpty
        ? 'KONST.POS'
        : settings.businessName.toUpperCase();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 70 : 220,
      color: AppTheme.surface,
      child: Column(children: [
        // Logo area
        GestureDetector(
          onTap: () => ref.read(sidebarCollapsedProvider.notifier).expand(),
          child: Container(
            padding: EdgeInsets.symmetric(
                vertical: 28, horizontal: isCollapsed ? 17 : 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset('assets/images/logo.png',
                      width: 36, height: 36, fit: BoxFit.cover),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'BuildEra',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Nav items
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                vertical: 12, horizontal: isCollapsed ? 8 : 10),
            child: Column(
              crossAxisAlignment: isCollapsed
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                ..._buildCategorizedNav(context, ref, isCollapsed),
                const SizedBox(height: 32),
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: SyncStatusBar(),
                  ),
              ],
            ),
          ),
        ),

        if (!compactMode)
          IconButton(
            onPressed: () =>
                ref.read(sidebarCollapsedProvider.notifier).toggle(),
            icon: Icon(
              isCollapsed
                  ? Icons.chevron_right_rounded
                  : Icons.chevron_left_rounded,
              color: AppTheme.textMuted,
            ),
          ),

        // Bottom
        Container(
          padding: EdgeInsets.all(isCollapsed ? 12 : 16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            mainAxisAlignment: isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.accent,
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        settings.ownerName.isEmpty
                            ? 'Admin'
                            : settings.ownerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('Owner',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  bool _isItemEnabled(_NavItem item, StoreSettings settings) {
    switch (item.index) {
      case 0: return settings.enableCashier;
      case 10:
      case 11: return settings.enablePurchase;
      case 2: return settings.enableTransactions;
      case 3:
      case 4: return settings.enableDebts;
      case 1: return settings.enableProducts;
      case 6: return settings.enableBarcode;
      case 5: return settings.enableAnalytics;
      case 8: return settings.enableBills;
      case 7: return true;
      default: return true;
    }
  }

  List<Widget> _buildCategorizedNav(
      BuildContext context, WidgetRef ref, bool isCollapsed) {
    final settings = ref.watch(settingsProvider);
    final strings = ref.watch(appStringsProvider);
    final visibleItems = _navItems.where((i) => _isItemEnabled(i, settings)).toList();

    final Map<String, List<_NavItem>> categories = {};
    for (final item in visibleItems) {
      final cat = item.category ?? 'LAINNYA';
      categories.putIfAbsent(cat, () => []).add(item);
    }

    final List<Widget> widgets = [];
    categories.forEach((cat, items) {
      if (!isCollapsed) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8, top: 16),
          child: Text(_getCategoryTitle(cat, strings),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    color: AppTheme.textMuted,
                  )),
        ));
      } else {
        widgets.add(const SizedBox(height: 16));
      }
      widgets.addAll(items.map((item) => _NavTile(
            item: item,
            selected: selectedIndex == item.index,
            onTap: () {
              onItemSelected(item.index);
              ref.read(sidebarCollapsedProvider.notifier).expand();
            },
            isCollapsed: isCollapsed,
          )));
    });
    return widgets;
  }
}

class _NavTile extends ConsumerWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  final bool isCollapsed;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
    required this.isCollapsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final label = _getNavItemLabel(item, strings);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? AppTheme.accent.withValues(alpha: 0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: isCollapsed ? 10 : 12, vertical: 11),
            width: double.infinity,
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Tooltip(
                  message: isCollapsed ? label : '',
                  child: Icon(
                    item.icon,
                    size: 20,
                    color: selected ? AppTheme.accent : AppTheme.textSecondary,
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            selected ? AppTheme.accent : AppTheme.textSecondary,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (selected) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
