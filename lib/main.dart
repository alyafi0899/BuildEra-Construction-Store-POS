import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'shared/widgets/sidebar.dart';
import 'features/cashier/presentation/pages/cashier_page.dart';
import 'features/products/presentation/pages/products_page.dart';
import 'features/inventory/presentation/pages/inventory_page.dart';
import 'features/payment/presentation/pages/transactions_page.dart';
import 'features/analytics/presentation/pages/dashboard_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
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
import 'shared/widgets/security_gate.dart';
import 'core/sync/services/local_database.dart';
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
    // Extract UID if provided (e.g., uid=ABC123XYZ or multi_window=ABC123XYZ)
    final uidArg = args.firstWhere((a) => a.contains('uid='), orElse: () => '');
    if (uidArg.isNotEmpty) {
      forcedUidForDisplay = uidArg.split('=')[1];
    }

    await LocalDatabase.init();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await initializeDateFormatting('id_ID', null);

    // Force show the window
    if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      await windowManager.ensureInitialized();
      WindowOptions windowOptions = const WindowOptions(
        size: Size(1024, 768),
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
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
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
    // Add timeout to prevent hanging if internet is extremely poor
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      debugPrint('BOOT: Firebase Init Timeout (Continuing Offline)');
      return Firebase.app(); // Attempt to use already initialized app or continue
    });
    
    if (!kIsWeb && Platform.isWindows) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true, // Enable offline cache for instant loading
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    await initializeDateFormatting('id_ID', null);

    // Ensure splash shows for at least 3 seconds
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 3000) {
      await Future.delayed(Duration(milliseconds: 3000 - elapsed));
    }

    runApp(const ProviderScope(child: KonstruksiPosApp()));
  } catch (e, stack) {
    debugPrint('BOOT ERROR: $e\n$stack');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText('Error during boot:\n$e\n\n$stack'),
          ),
        ),
      ),
    ));
  }
}

class KonstruksiPosApp extends ConsumerWidget {
  const KonstruksiPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    return MaterialApp(
      title: 'BuildEra',
      debugShowCheckedModeBanner: false,
      theme: AppThemes.getTheme(mode),
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
  // Main Navigation Destinations for Bottom Bar
  final _mainPages = [
    const AnalyticsPage(), // Dashboard
    const ProductsPage(),
    const CashierPage(),
    const TransactionsPage(),
    const SettingsPage(),
  ];

  // Secondary pages (accessible via dashboard or other links)
  // We'll keep the IndexedStack for now but refactor how we switch
  final _allPages = [
    const CashierPage(),           // 0
    const ProductsPage(),          // 1
    const InventoryPage(),         // 2
    const TransactionsPage(),      // 3
    const PiutangDashboard(),      // 4
    const CustomerListPage(),       // 5
    const DashboardPage(),         // 6
    const BarcodeManagementPage(), // 7
    const SettingsPage(),          // 8
    const BillsPage(),             // 9
    const CustomerDisplayPage(),   // 10
  ];

  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(navigationIndexProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;
    
    // Mapping for Bottom Navigation Bar (if we only want 5 main tabs)
    int getBottomIdx(int currentIdx) {
      if (currentIdx == 6) return 0; // Analytics -> Dashboard
      if (currentIdx == 1) return 1; // Products
      if (currentIdx == 0) return 2; // Cashier
      if (currentIdx == 3) return 3; // Transactions
      if (currentIdx == 8) return 4; // Settings
      return 0; // Default to Dashboard
    }

    void onBottomTabTapped(int index) {
      const map = [6, 1, 0, 3, 8];
      ref.read(navigationIndexProvider.notifier).setIndex(map[index]);
    }

    // Auto-lock on navigation
    ref.listen(navigationIndexProvider, (prev, next) {
      if (prev != next) {
        ref.read(pinUnlockProvider.notifier).lock();
      }
    });
    
    // Listen to cart changes for Customer Display Sync
    ref.listen(cartProvider, (prev, next) {
      final user = ref.read(authStateProvider).value;
      final settings = ref.read(appSettingsProvider);
      if (user != null && settings.isCustomerDisplayEnabled) {
        CustomerDisplayBridge.syncCart(user.uid, next);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Row(
        children: [
          if (!isMobile)
            AppSidebar(
              selectedIndex: idx,
              onItemSelected: (i) => ref.read(navigationIndexProvider.notifier).setIndex(i),
            ),
          Expanded(
            child: IndexedStack(index: idx, children: _allPages),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: getBottomIdx(idx),
              onTap: onBottomTabTapped,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Beranda'),
                BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Produk'),
                BottomNavigationBarItem(icon: Icon(Icons.point_of_sale_rounded), label: 'Kasir'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Transaksi'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Sistem'),
              ],
            )
          : null,
    );
  }
}
