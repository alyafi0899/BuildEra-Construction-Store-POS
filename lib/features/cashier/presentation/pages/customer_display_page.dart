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
          // Left Side: Promotional area or branding
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
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Belanja Kebutuhan Bangunan Jadi Lebih Mudah',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Right Side: Live Cart Details
          Container(
            width: 450,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(left: BorderSide(color: AppTheme.border)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_rounded, color: AppTheme.accent),
                      const SizedBox(width: 12),
                      Text('Ringkasan Belanja', style: Theme.of(context).textTheme.headlineMedium),
                    ],
                  ),
                ),
                
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: cart.items.length,
                    itemBuilder: (context, i) {
                      final item = cart.items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('${Formatters.decimal(item.quantity)} ${item.selectedUnit.unitName} x ${Formatters.currency(item.soldPrice)}'),
                                ],
                              ),
                            ),
                            Text(Formatters.currency(item.subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.accent)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                Container(
                  padding: const EdgeInsets.all(32),
                  color: AppTheme.surfaceAlt,
                  child: Column(
                    children: [
                      _buildRow('Subtotal', Formatters.currency(cart.grossSubtotal)),
                      if (cart.totalDiscount > 0)
                        _buildRow('Potongan', '- ${Formatters.currency(cart.totalDiscount)}', color: AppTheme.success),
                      const Divider(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL AKHIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                          Text(Formatters.currency(cart.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: AppTheme.accent)),
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

  Widget _buildRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
