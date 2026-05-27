// lib/app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/formatters.dart';
import 'features/cashier/presentation/pages/cashier_page.dart';
import 'features/inventory/presentation/pages/inventory_page.dart';
import 'features/payment/presentation/pages/transactions_page.dart';
import 'features/payment/presentation/providers/transaction_provider.dart';
import 'features/products/presentation/pages/products_page.dart';
import 'features/products/presentation/providers/product_provider.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'shared/widgets/app_sidebar.dart';

final currentRouteProvider = StateProvider<String>((ref) => AppRoutes.cashier);

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = ref.watch(currentRouteProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          AppSidebar(
            currentRoute: currentRoute,
            onNavigate: (route) =>
                ref.read(currentRouteProvider.notifier).state = route,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _buildPage(currentRoute),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(String route) {
    switch (route) {
      case AppRoutes.cashier:      return const CashierPage(key: ValueKey('cashier'));
      case AppRoutes.products:     return const ProductsPage(key: ValueKey('products'));
      case AppRoutes.inventory:    return const InventoryPage(key: ValueKey('inventory'));
      case AppRoutes.transactions: return const TransactionsPage(key: ValueKey('transactions'));
      case AppRoutes.settings:     return const SettingsPage(key: ValueKey('settings'));
      default:                     return const CashierPage(key: ValueKey('cashier'));
    }
  }
}

// ─── TOP BAR ─────────────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySales = ref.watch(todaySalesProvider);
    final lowStock = ref.watch(lowStockProductsProvider);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded, color: AppColors.success, size: 14),
          const SizedBox(width: 6),
          Text(
            'Penjualan hari ini: ${AppFormatters.formatCurrency(todaySales)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          if (lowStock.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warningContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 14),
                const SizedBox(width: 6),
                Text(
                  '${lowStock.length} produk stok rendah',
                  style: const TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          const SizedBox(width: 16),
          _ClockWidget(),
        ],
      ),
    );
  }
}

class _ClockWidget extends StatefulWidget {
  @override
  State<_ClockWidget> createState() => _ClockWidgetState();
}

class _ClockWidgetState extends State<_ClockWidget> {
  late final Stream<DateTime> _stream;

  @override
  void initState() {
    super.initState();
    _stream = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _stream,
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return Row(children: [
          const Icon(Icons.access_time_rounded,
              color: AppColors.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(
            AppFormatters.formatDateTime(now),
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontFamily: 'monospace'),
          ),
        ]);
      },
    );
  }
}
