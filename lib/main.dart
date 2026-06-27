import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'shared/widgets/sidebar.dart';
import 'features/cashier/presentation/pages/cashier_page.dart';
import 'features/products/presentation/pages/products_page.dart';
import 'features/inventory/presentation/pages/inventory_page.dart';
import 'features/payment/presentation/pages/transactions_page.dart';
import 'features/analytics/presentation/pages/analytics_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'features/debts/presentation/pages/piutang_dashboard.dart';
import 'features/debts/presentation/pages/customer_list_page.dart';
import 'features/inventory/presentation/pages/bills_page.dart';
import 'features/settings/providers/app_settings_provider.dart';
import 'features/cashier/presentation/pages/customer_display_page.dart';
import 'features/cashier/providers/cart_provider.dart';
import 'features/cashier/providers/customer_display_provider.dart';
import 'features/cashier/providers/scan_mode_provider.dart';
import 'features/cashier/presentation/widgets/barcode_listener.dart';
import 'features/products/providers/product_provider.dart';
import 'features/products/presentation/pages/barcode_management_page.dart';
import 'features/inventory/providers/restock_provider.dart';
import 'features/payment/providers/transaction_provider.dart';
import 'features/debts/providers/debt_repository.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/auth/providers/auth_provider.dart';
import 'core/sync/services/local_database.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'shared/widgets/splash_screen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Handle Secondary Windows (Customer Display) ASAP
  if (args.isNotEmpty && args.contains('multi_window')) {
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
        backgroundColor: Color(0xFF0F1117),
        title: 'Tampilan Pelanggan - BuildEra',
      );
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    runApp(ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const CustomerDisplayPage(),
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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    if (!kIsWeb && Platform.isWindows) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
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
    return MaterialApp(
      title: 'BuildEra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
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
  int _idx = 0;
  final _pages = [
    const CashierPage(),
    const ProductsPage(),
    const InventoryPage(),
    const TransactionsPage(),
    const PiutangDashboard(),
    const CustomerListPage(),
    const AnalyticsPage(),
    const BarcodeManagementPage(),
    const SettingsPage(),
    const BillsPage(),
    const CustomerDisplayPage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Listen to cart changes for Customer Display Sync
    ref.listen(cartProvider, (prev, next) {
      final user = ref.read(authStateProvider).value;
      final settings = ref.read(appSettingsProvider);
      if (user != null && settings.isCustomerDisplayEnabled) {
        CustomerDisplayBridge.syncCart(user.uid, next);
      }
    });

    // Keep essential providers warm for backup and analytics
    ref.watch(productsProvider);
    ref.watch(restockHistoryProvider);
    ref.watch(transactionsProvider);
    ref.watch(customersProvider);

    final autoAdd = ref.watch(scanModeProvider);
    final shell = Row(children: [
      AppSidebar(
        selectedIndex: _idx,
        onItemSelected: (i) => setState(() => _idx = i),
      ),
      Expanded(
        child: IndexedStack(index: _idx, children: _pages),
      ),
    ]);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: BarcodeListener(
        autoAdd: autoAdd,
        child: shell,
      ),
    );
  }
}
