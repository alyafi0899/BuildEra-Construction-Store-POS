import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/settings/providers/settings_provider.dart';
import 'core/utils/responsive_breakpoints.dart';
import 'shared/widgets/sidebar.dart';
import 'features/cashier/presentation/pages/cashier_page.dart';
import 'features/products/presentation/pages/products_page.dart';
import 'features/payment/presentation/pages/transactions_page.dart';
import 'features/analytics/presentation/pages/analytics_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/purchase/presentation/pages/purchase_page.dart';
import 'features/purchase/presentation/pages/purchase_history_page.dart';
import 'features/debts/presentation/pages/piutang_dashboard.dart';
import 'features/debts/presentation/pages/customer_list_page.dart';
import 'features/inventory/presentation/pages/bills_page.dart';
import 'features/settings/providers/app_settings_provider.dart';
import 'features/cashier/presentation/pages/customer_display_page.dart';
import 'features/cashier/providers/cart_provider.dart';
import 'features/cashier/providers/customer_display_provider.dart';
import 'features/products/providers/product_provider.dart';
import 'features/products/presentation/pages/barcode_management_page.dart';
import 'features/inventory/providers/restock_provider.dart';
import 'features/payment/providers/transaction_provider.dart';
import 'features/debts/providers/debt_repository.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/subscription/providers/subscription_provider.dart';
import 'core/sync/services/local_database.dart';
import 'core/sync/providers/sync_provider.dart';
import 'core/providers/navigation_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'shared/widgets/splash_screen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Handle Secondary Windows (Customer Display) ASAP
  // Use more flexible check for arguments
  final isMultiWindow = args.any((a) => a.contains('multi_window'));

  if (isMultiWindow) {
    // 1. Initialize window manager immediately so we can show errors if boot fails
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1060, 768),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        title: 'Tampilan Pelanggan - BuildEra',
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    // Extract UID if provided (e.g., uid=ABC123XYZ or multi_window=ABC123XYZ)
    final uidArg = args.firstWhere((a) => a.contains('uid='), orElse: () => '');
    if (uidArg.isNotEmpty) {
      forcedUidForDisplay = uidArg.split('=')[1];
    }

    // Try initialization but ignore Hive errors if already initialized by another process
    // Actually, for secondary window, we DON'T need local database at all.
    // It only needs Supabase to sync the cart.
    // try {
    //   await LocalDatabase.init();
    // } catch (e) {
    //   debugPrint('DEBUG: Multi-window database init warning: $e');
    // }

    await Supabase.initialize(
      url: 'https://xlkncjimgriwrxxpweue.supabase.co',
      publishableKey: 'sb_publishable_RfxfRsQv2zm-Gt0rdTQP0w_23dkq2Zh',
    );
    await initializeDateFormatting('id_ID', null);

    runApp(ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          final mode = ref.watch(themeProvider);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppThemes.getTheme(mode),
            home: const CustomerDisplayPage(),
          );
        },
      ),
    ));
    return;
  }

  await LocalDatabase.init();

  // 1. Initialize Window Manager ASAP for Windows/Desktop
  final isDesktop =
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  if (isDesktop) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1500, 800),
      minimumSize: Size(360, 600),
      center: true,
      backgroundColor: Color(0xFF0F1117),
      skipTaskbar: false,
      title: 'BuildEra',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions);
    await windowManager.show();
    await windowManager.focus();
  }

  // 2. Start initialization timer for Brand Identity (Min 3.0s)
  final stopwatch = Stopwatch()..start();

  // Show splash screen immediately
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.dark,
    home: const SplashScreen(status: 'Menginisialisasi Sistem...'),
  ));

  // Yield to allow the splash screen to render
  await Future.delayed(const Duration(milliseconds: 100));

  try {
    // Perform all heavy lifting while splash is showing
    await Supabase.initialize(
      url: 'https://xlkncjimgriwrxxpweue.supabase.co',
      publishableKey: 'sb_publishable_RfxfRsQv2zm-Gt0rdTQP0w_23dkq2Zh',
    );

    await initializeDateFormatting('id_ID', null);

    // Ensure splash shows for at least 3 seconds
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 3000) {
      await Future.delayed(Duration(milliseconds: 3000 - elapsed));
    }

    runApp(const ProviderScope(child: KonstruksiPosApp()));
  } catch (e, stack) {
    debugPrint('BOOT ERROR: $e\n$stack');

    // Ensure window is shown even on boot error
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      try {
        await windowManager.ensureInitialized();
        await windowManager.show();
      } catch (_) {}
    }

    runApp(_BootErrorApp(error: e.toString()));
  }
}

class _BootErrorApp extends StatelessWidget {
  final String error;
  const _BootErrorApp({required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        backgroundColor: AppTheme.bg,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 48,
                          color: AppTheme.warning,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Koneksi Internet Diperlukan Saat Membuka Aplikasi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Aplikasi membutuhkan jaringan internet pada awal dibuka untuk verifikasi keamanan akun & autentikasi Sesi.\n\nSetelah berhasil dibuka, transaksi kasir & kelola POS dapat dijalankan secara offline.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          main([]);
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text('HUBUNGKAN & COBA LAGI'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class KonstruksiPosApp extends ConsumerWidget {
  const KonstruksiPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playBillingBootstrapProvider);
    final mode = ref.watch(themeProvider);
    final appSettings = ref.watch(appSettingsProvider);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'BuildEra',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.getTheme(mode),
      builder: (context, child) {
        if (appSettings.displayScale == 1.0) return child!;

        final size = MediaQuery.of(context).size;
        final scale = appSettings.displayScale;

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size / scale,
            devicePixelRatio: MediaQuery.of(context).devicePixelRatio * scale,
          ),
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: size.width / scale,
              height: size.height / scale,
              child: child,
            ),
          ),
        );
      },
      home: const AuthGate(),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final _pages = [
    const CashierPage(),
    const ProductsPage(),
    const TransactionsPage(),
    const PiutangDashboard(),
    const CustomerListPage(),
    const AnalyticsPage(),
    const BarcodeManagementPage(),
    const SettingsPage(),
    const BillsPage(),
    const CustomerDisplayPage(),
    const PurchasePage(),
    const PurchaseHistoryPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(navigationIndexProvider);
    final width = MediaQuery.sizeOf(context).width;
    final responsiveSize = ResponsiveBreakpoints.classify(width);
    final isPhone = responsiveSize == ResponsiveSize.phone;
    final isTablet = responsiveSize == ResponsiveSize.tablet;

    // Listen to cart changes for Customer Display Sync
    ref.listen(cartProvider, (prev, next) {
      final user = ref.read(authStateProvider).value;
      final settings = ref.read(appSettingsProvider);
      if (user != null && settings.isCustomerDisplayEnabled) {
        CustomerDisplayBridge.syncCart(user.uid, next);
      }
    });

    // Keep essential providers warm for backup and analytics
    ref.watch(syncProvider);
    ref.watch(productsProvider);
    ref.watch(restockHistoryProvider);
    ref.watch(transactionsProvider);
    ref.watch(customersProvider);

    final pageStack = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) =>
          ref.read(sidebarCollapsedProvider.notifier).collapse(),
      child: IndexedStack(index: idx, children: _pages),
    );

    final shell = isPhone
        ? pageStack
        : Row(
            children: [
              AppSidebar(
                selectedIndex: idx,
                compactMode: isTablet,
                onItemSelected: (i) =>
                    ref.read(navigationIndexProvider.notifier).setIndex(i),
              ),
              Expanded(child: pageStack),
            ],
          );

    return Scaffold(
      backgroundColor: AppTheme.bg,
      resizeToAvoidBottomInset: isPhone,
      body: SafeArea(
        top: true,
        bottom: false,
        child: shell,
      ),
      bottomNavigationBar: isPhone
          ? NavigationBar(
              selectedIndex: _phoneDestinationIndex(idx),
              onDestinationSelected: (destination) {
                if (destination == 4) {
                  _showMoreDestinations(context, ref, idx);
                  return;
                }
                const destinations = [0, 1, 2, 3];
                ref
                    .read(navigationIndexProvider.notifier)
                    .setIndex(destinations[destination]);
              },
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.point_of_sale_rounded), label: 'Kasir'),
                NavigationDestination(
                    icon: Icon(Icons.inventory_2_rounded), label: 'Produk'),
                NavigationDestination(
                    icon: Icon(Icons.receipt_long_rounded), label: 'Transaksi'),
                NavigationDestination(
                    icon: Icon(Icons.account_balance_wallet_rounded),
                    label: 'Piutang'),
                NavigationDestination(
                    icon: Icon(Icons.more_horiz_rounded), label: 'Lainnya'),
              ],
            )
          : null,
    );
  }

  int _phoneDestinationIndex(int pageIndex) {
    const destinations = [0, 1, 2, 3];
    final index = destinations.indexOf(pageIndex);
    return index < 0 ? 4 : index;
  }

  void _showMoreDestinations(
      BuildContext context, WidgetRef ref, int selectedIndex) {
    final settings = ref.read(settingsProvider);

    final allDestinations = <(int, String, IconData, bool)>[
      (10, 'Pembelian', Icons.local_shipping_rounded, settings.enablePurchase),
      (11, 'Riwayat Beli', Icons.history_edu_rounded, settings.enablePurchase),
      (4, 'Pelanggan', Icons.people_rounded, settings.enableDebts),
      (6, 'Label Barcode', Icons.qr_code_2_rounded, settings.enableBarcode),
      (5, 'Analitik', Icons.bar_chart_rounded, settings.enableAnalytics),
      (8, 'Tagihan', Icons.receipt_rounded, settings.enableBills),
      (7, 'Pengaturan', Icons.settings_rounded, true),
      (9, 'Tampilan Pelanggan', Icons.display_settings_rounded, true),
    ];

    final filtered = allDestinations.where((d) => d.$4).toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final destination in filtered)
              ListTile(
                leading: Icon(destination.$3),
                title: Text(destination.$2),
                selected: selectedIndex == destination.$1,
                onTap: () {
                  Navigator.pop(sheetContext);
                  ref
                      .read(navigationIndexProvider.notifier)
                      .setIndex(destination.$1);
                },
              ),
          ],
        ),
      ),
    );
  }
}
