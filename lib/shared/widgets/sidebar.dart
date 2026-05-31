import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';

class _NavItem {
  final IconData icon;
  final String   label;
  final int      index;
  const _NavItem(this.icon, this.label, this.index);
}

const _navItems = [
  _NavItem(Icons.point_of_sale_rounded,       'Kasir',       0),
  _NavItem(Icons.inventory_2_rounded,         'Produk',      1),
  _NavItem(Icons.warehouse_rounded,           'Inventori',   2),
  _NavItem(Icons.receipt_long_rounded,        'Transaksi',   3),
  _NavItem(Icons.bar_chart_rounded,           'Analitik',    4),
];

class AppSidebar extends StatelessWidget {
  final int      selectedIndex;
  final ValueChanged<int> onItemSelected;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      color: AppTheme.surface,
      child: Column(children: [
        // Logo area
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.border)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.construction, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('KONST.POS',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color:       AppTheme.accent,
                          fontSize:    14,
                          fontWeight:  FontWeight.w800,
                          letterSpacing: 1.5,
                        )),
                Text('v${AppConstants.appVersion}',
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ]),
          ]),
        ),

        // Nav items
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 8, top: 4),
                  child: Text('MENU',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w700,
                          )),
                ),
                ..._navItems.map((item) => _NavTile(
                      item:     item,
                      selected: selectedIndex == item.index,
                      onTap:    () => onItemSelected(item.index),
                    )),
              ],
            ),
          ),
        ),

        // Bottom
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(children: [
            const CircleAvatar(
              radius:          16,
              backgroundColor: AppTheme.accent,
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Admin', style: Theme.of(context).textTheme.titleMedium),
              Text('Kasir', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool     selected;
  final VoidCallback onTap;

  const _NavTile({required this.item, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color:        selected ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
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
                color: selected ? AppTheme.accent : AppTheme.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                item.label,
                style: TextStyle(
                  color:      selected ? AppTheme.accent : AppTheme.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  fontSize:   14,
                ),
              ),
              if (selected) ...[
                const Spacer(),
                Container(
                  width: 4, height: 4,
                  decoration: const BoxDecoration(
                    color:  AppTheme.accent,
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
