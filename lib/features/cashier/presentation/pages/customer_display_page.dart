import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/customer_display_provider.dart';

class CustomerDisplayPage extends ConsumerWidget {
  const CustomerDisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(customerDisplayCartProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: cartAsync.when(
        data: (cart) {
          if (cart == null) return const _CenterMessage(text: 'Silakan Login di Layar Utama');
          
          return Row(
            children: [
              // Left: Branding
              Expanded(
                flex: 1,
                child: Container(
                  color: colorScheme.primary,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/images/logo.png', width: 120, height: 120),
                        const SizedBox(height: 24),
                        Text('BuildEra',
                          style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 42)),
                        const SizedBox(height: 8),
                        Text('Material and Construction POS',
                          style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.9), fontSize: 18, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Bangun. Kelola. Kembangkan.',
                          style: TextStyle(color: colorScheme.onPrimary.withValues(alpha: 0.7), fontSize: 16, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Right: Cart Details
              Container(
                width: 500,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  border: Border(left: BorderSide(color: colorScheme.outline)),
                ),
                child: Column(
                  children: [
                    _buildHeader(context),
                    Expanded(child: _buildItemsList(context, cart)),
                    _buildTotals(context, cart),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: colorScheme.outline))),
      child: Row(
        children: [
          Icon(Icons.shopping_cart_rounded, color: colorScheme.primary, size: 28),
          const SizedBox(width: 16),
          Text('Daftar Belanja', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    );
  }

  Widget _buildItemsList(BuildContext context, dynamic cart) {
    final colorScheme = Theme.of(context).colorScheme;
    if (cart.items.isEmpty) {
      return Center(child: Text('Menunggu pesanan...', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 18)));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => Divider(color: colorScheme.outline, height: 32),
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
                    style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(Formatters.currency(item.subtotal), 
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.primary)),
          ],
        );
      },
    );
  }

  Widget _buildTotals(BuildContext context, dynamic cart) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(40),
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          _row(context, 'Subtotal', Formatters.currency(cart.grossSubtotal)),
          if (cart.totalDiscount > 0)
            _row(context, 'Potongan', '- ${Formatters.currency(cart.totalDiscount)}', color: const Color(0xFF2ECC71)),
          if (cart.taxEnabled)
            _row(context, 'PPN (11%)', Formatters.currency(cart.taxAmount)),
          Divider(height: 48, thickness: 2, color: colorScheme.outline),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
              Text(Formatters.currency(cart.total), 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 42, color: colorScheme.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {Color? color}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 18, color: colorScheme.onSurface.withValues(alpha: 0.6))),
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
    return Center(child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 20)));
  }
}
