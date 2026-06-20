import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/customer_display_provider.dart';

class CustomerDisplayPage extends ConsumerWidget {
  const CustomerDisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(customerDisplayCartProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: cartAsync.when(
        data: (cart) {
          if (cart == null) return const _CenterMessage(text: 'Silakan Login di Layar Utama');
          
          return Row(
            children: [
              // Left: Branding
              Expanded(
                flex: 1,
                child: Container(
                  color: AppTheme.accent,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/logo.png', width: 120, height: 120),
                        const SizedBox(height: 24),
                        const Text('BuildEra',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 42)),
                        const SizedBox(height: 8),
                        const Text('Material and Construction POS',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        const Text('Bangun. Kelola. Kembangkan.',
                          style: TextStyle(color: Colors.white70, fontSize: 16, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Right: Cart Details
              Container(
                width: 500,
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border: Border(left: BorderSide(color: AppTheme.border)),
                ),
                child: Column(
                  children: [
                    _buildHeader(context),
                    Expanded(child: _buildItemsList(cart)),
                    _buildTotals(cart),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const _CenterMessage(text: 'Menghubungkan ke Kasir...'),
        error: (e, _) => _CenterMessage(text: 'Error: $e'),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_rounded, color: AppTheme.accent, size: 28),
          const SizedBox(width: 16),
          Text('Daftar Belanja', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildItemsList(dynamic cart) {
    if (cart.items.isEmpty) {
      return const Center(child: Text('Menunggu pesanan...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const Divider(color: AppTheme.border, height: 32),
      itemBuilder: (context, i) {
        final item = cart.items[i];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('${Formatters.decimal(item.quantity)} ${item.selectedUnit.unitName} x ${Formatters.currency(item.soldPrice)}',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(Formatters.currency(item.subtotal), 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.accent)),
          ],
        );
      },
    );
  }

  Widget _buildTotals(dynamic cart) {
    return Container(
      padding: const EdgeInsets.all(40),
      color: AppTheme.surfaceAlt,
      child: Column(
        children: [
          _row('Subtotal', Formatters.currency(cart.grossSubtotal)),
          if (cart.totalDiscount > 0)
            _row('Potongan', '- ${Formatters.currency(cart.totalDiscount)}', color: AppTheme.success),
          if (cart.taxEnabled)
            _row('PPN (11%)', Formatters.currency(cart.taxAmount)),
          const Divider(height: 48, thickness: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
              Text(Formatters.currency(cart.total), 
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 42, color: AppTheme.accent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final String text;
  const _CenterMessage({required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 20)));
  }
}
