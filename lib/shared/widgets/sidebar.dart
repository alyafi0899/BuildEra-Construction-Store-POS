import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/settings/providers/settings_provider.dart';
import '../../core/sync/widgets/sync_status_bar.dart';

class _NavItem {
  final IconData icon;
  final String   label;
  final int      index;
  final String?  category;
  const _NavItem(this.icon, this.label, this.index, [this.category]);
}

const _navItems = [
  // OPERASIONAL
  _NavItem(Icons.point_of_sale_rounded,       'Kasir',       0, 'OPERASIONAL'),
  _NavItem(Icons.receipt_long_rounded,        'Transaksi',   3, 'OPERASIONAL'),
  _NavItem(Icons.account_balance_wallet_rounded, 'Piutang',   4, 'OPERASIONAL'),
  _NavItem(Icons.people_rounded,               'Pelanggan',   5, 'OPERASIONAL'),

  // INVENTORI
  _NavItem(Icons.inventory_2_rounded,         'Produk',      1, 'INVENTORI'),
  _NavItem(Icons.warehouse_rounded,           'Inventori',   2, 'INVENTORI'),
  _NavItem(Icons.qr_code_2_rounded,           'Label Barcode', 7, 'INVENTORI'),

  // FINANSIAL
  _NavItem(Icons.bar_chart_rounded,           'Analitik',    6, 'FINANSIAL'),
  _NavItem(Icons.receipt_rounded,              'Tagihan',     9, 'FINANSIAL'),

  // SISTEM
  _NavItem(Icons.settings_rounded,            'Pengaturan',  8, 'SISTEM'),
];

class AppSidebar extends ConsumerWidget {
  final int      selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final businessName = settings.businessName.isEmpty ? 'KONST.POS' : settings.businessName.toUpperCase();
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 220,
      color: colorScheme.surface,
      child: Column(children: [
        // Logo area
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colorScheme.outline)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/logo.png', width: 36, height: 36, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('BuildEra',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                            color:       colorScheme.onSurface,
                            fontSize:    15,
                            fontWeight:  FontWeight.w900,
                            letterSpacing: 1.0,
                          )),
                  Text(businessName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                            color:       colorScheme.primary,
                            fontSize:    10,
                            fontWeight:  FontWeight.w600,
                            letterSpacing: 0.5,
                          )),
                ]),
              ),
            ]),
          ]),
        ),

        // Nav items
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildCategorizedNav(context),
                const SizedBox(height: 32),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: SyncStatusBar(),
                ),
              ],
            ),
          ),
        ),

        // Bottom
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: colorScheme.outline)),
          ),
          child: Row(children: [
            CircleAvatar(
              radius:          16,
              backgroundColor: colorScheme.primary,
              child: Icon(Icons.person, color: colorScheme.onPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(settings.ownerName.isEmpty ? 'Admin' : settings.ownerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                Text('Owner', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _buildCategorizedNav(BuildContext context) {
    final Map<String, List<_NavItem>> categories = {};
    for (final item in _navItems) {
      final cat = item.category ?? 'LAINNYA';
      categories.putIfAbsent(cat, () => []).add(item);
    }

    final List<Widget> widgets = [];
    categories.forEach((cat, items) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(left: 10, bottom: 8, top: 16),
        child: Text(cat,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                )),
      ));
      widgets.addAll(items.map((item) => _NavTile(
            item:     item,
            selected: selectedIndex == item.index,
            onTap:    () => onItemSelected(item.index),
          )));
    });
    return widgets;
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool     selected;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color:        selected ? colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap:        onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Icon(
                item.icon,
                size:  20,
                color: selected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color:      selected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.6),
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize:   14,
                ),
              ),
              if (selected) ...[
                const Spacer(),
                Container(
                  width: 4, height: 4,
                  decoration: BoxDecoration(
                    color:  colorScheme.primary,
                    shape:  BoxShape.circle,
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
