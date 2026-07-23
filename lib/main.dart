import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
                              import 'core/theme/theme_provider.dart';
import 'shared/widgets/sidebar.dart';
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
  final isMultiWindow = args.any((a) => a.contains('multi_window'));
  
  if (isMultiWindow) {
    final uidArg = args.firstWhere((a) => a.contains('uid='), orElse: () => '');
    if (uidArg.isNotEmpty) {
      forcedUidForDisplay = uidArg.split('=')[1];
    }

    await LocalDatabase.init();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await initializeDateFormatting('id_ID', null);

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
          final theme = ref.watch(themeProvider);
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: theme,
            home: const CustomerDisplayPage(),
          );
        },
      ),
    ));
    return;
  }

  await LocalDatabase.init();

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

  final stopwatch = Stopwatch()..start();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppThemes.darkOrange,
    home: const SplashScreen(status: 'Menginisialisasi Sistem...'),
  ));

  await Future.delayed(const Duration(milliseconds: 100));

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      debugPrint('BOOT: Firebase Init Timeout (Continuing Offline)');
      return Firebase.app();
    });
    
    if (!kIsWeb && Platform.isWindows) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    await initializeDateFormatting('id_ID', null);

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
    final theme = ref.watch(themeProvider);
    return MaterialApp(
      title: 'BuildEra',
      debugShowCheckedModeBanner: false,
      theme: theme,
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
  // Navigation specialized for Manager role (Android)
  final _managerPages = [
    const DashboardPage(),         // 0
    const ProductsPage(),          // 1
    const InventoryPage(),         // 2
    const TransactionsPage(),      // 3
    const CustomerListPage(),       // 4
    const BillsPage(),             // 5
    const SettingsPage(),          // 6
  ];

  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(navigationIndexProvider);
    final isMobile = MediaQuery.of(context).size.width < 800;
    
    // Mapping for Bottom Navigation Bar (Manager Role)
    // 0: Dashboard, 1: Products, 2: Inventory, 3: Transactions, 4: Piutang, 5: Bills, 6: Settings
    int getBottomIdx(int currentIdx) {
      if (currentIdx > 6) return 0;
      return currentIdx;
    }

    void onBottomTabTapped(int index) {
      ref.read(navigationIndexProvider.notifier).setIndex(index);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Row(
        children: [
          if (!isMobile)
            AppSidebar(
              selectedIndex: idx,
              onItemSelected: (i) => ref.read(navigationIndexProvider.notifier).setIndex(i),
            ),
          Expanded(
            child: IndexedStack(
              index: getBottomIdx(idx), 
              children: _managerPages
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
              currentIndex: getBottomIdx(idx),
              onTap: onBottomTabTapped,
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
                BottomNavigationBarItem(icon: Icon(Icons.inventory_2_rounded), label: 'Produk'),
                BottomNavigationBarItem(icon: Icon(Icons.warehouse_rounded), label: 'Stok'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'Transaksi'),
                BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Piutang'),
                BottomNavigationBarItem(icon: Icon(Icons.receipt_rounded), label: 'Tagihan'),
                BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Sistem'),
              ],
            )
          : null,
    );
  }
}
