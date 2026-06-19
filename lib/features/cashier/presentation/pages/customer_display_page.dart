import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/customer_display_provider.dart';

class CustomerDisplayPage extends ConsumerStatefulWidget {
  const CustomerDisplayPage({super.key});

  @override
  ConsumerState<CustomerDisplayPage> createState() => _CustomerDisplayPageState();
}

class _CustomerDisplayPageState extends ConsumerState<CustomerDisplayPage> {
  @override
  void initState() {
    super.initState();
    // Initialize the bridge to listen for updates from the main window
    CustomerDisplayBridge.init(ref);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(customerCartProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(
        children: [
          // Left Side: Branding
          Expanded(
            flex: 1,
            child: Container(
              color: AppTheme.accent,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.construction, color: Colors.white, size: 100),
                    const SizedBox(height: 24),
                    Text(
                      'KONSTRUKSI POS',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Terima Kasih Telah Berbelanja',
                      style: TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Right Side: Cart Summary (Duplicated logic from Cashier Page)
          Container(
            width: 500,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(left: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_cart_rounded, color: AppTheme.accent, size: 28),
                      const SizedBox(width: 16),
                      Text('Daftar Belanja', style: Theme.of(context).textTheme.headlineMedium),
                    ],
                  ),
                ),
                
                Expanded(
                  child: cart.items.isEmpty 
                    ? const Center(
                        child: Text('Menunggu pesanan...', 
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 18)))
                    : ListView.separated(
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
                                    Text(item.product.name, 
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                      ),
                ),
                
                // Totals
                Container(
                  padding: const EdgeInsets.all(40),
                  color: AppTheme.surfaceAlt,
                  child: Column(
                    children: [
                      _buildRow('Subtotal', Formatters.currency(cart.grossSubtotal), fontSize: 18),
                      if (cart.totalDiscount > 0)
                        _buildRow('Potongan', '- ${Formatters.currency(cart.totalDiscount)}', 
                          color: AppTheme.success, fontSize: 18),
                      if (cart.taxEnabled)
                        _buildRow('PPN (11%)', Formatters.currency(cart.taxAmount), fontSize: 18),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? color, double fontSize = 16}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, color: AppTheme.textSecondary)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
