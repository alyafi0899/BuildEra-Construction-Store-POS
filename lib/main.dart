import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'shared/widgets/sidebar.dart';
import 'features/cashier/presentation/pages/cashier_page.dart';
import 'features/products/presentation/pages/products_page.dart';
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
import 'features/products/providers/product_provider.dart';
import 'features/products/presentation/pages/barcode_management_page.dart';
import 'features/inventory/providers/restock_provider.dart';
import 'features/payment/providers/transaction_provider.dart';
import 'features/debts/providers/debt_repository.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/pin_unlock_provider.dart';
import 'core/sync/services/local_database.dart';
import 'core/providers/navigation_provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'shared/widgets/splash_screen.dart';
import 'shared/widgets/security_gate.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 0. Force Landscape Orientation (Mobile)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
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

    // Milestone 1: Initialize Supabase
    await Supabase.initialize(
      url: 'https://xlkncjimgriwrxxpweue.supabase.co',
      anonKey: 'sb_publishable_RfxfRsQv2zm-Gt0rdTQP0w_23dkq2Zh', // Use publishableKey if version supports it
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
  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
  if (isDesktop) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1500, 800),
      minimumSize: Size(1500, 700), // Enforce landscape minimum
      center: true,
      backgroundColor: Color(0xFF0F1117),
      skipTaskbar: false,
      title: 'BuildEra',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions);
    await windowManager.show();
    await windowManager.focus();
    
    // Ensure it's not starting in portrait-like dimensions if maximized
    if (Platform.isWindows) {
      await windowManager.setAspectRatio(1.6); // Lock aspect ratio to landscape (16:10 or 16:9)
    }
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
    // Milestone 1: Initialize Supabase
    await Supabase.initialize(
      url: 'https://xlkncjimgriwrxxpweue.supabase.co',
      anonKey: 'sb_publishable_RfxfRsQv2zm-Gt0rdTQP0w_23dkq2Zh', // Use publishableKey if version supports it
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
    // Re-enforce orientation lock on app build
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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
  final _pages = [
    const CashierPage(),
    const PinGate(pageKey: 'products', child: ProductsPage()),
    const PinGate(pageKey: 'transactions', child: TransactionsPage()),
    const PinGate(pageKey: 'debts', child: PiutangDashboard()),
    const PinGate(pageKey: 'debts', child: CustomerListPage()),
    const PinGate(pageKey: 'analytics', child: AnalyticsPage()),
    const PinGate(pageKey: 'products', child: BarcodeManagementPage()),
    const SettingsPage(),
    const PinGate(pageKey: 'inventory', child: BillsPage()),
    const CustomerDisplayPage(),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = ref.watch(navigationIndexProvider);
    
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

    // Keep essential providers warm for backup and analytics
    ref.watch(productsProvider);
    ref.watch(restockHistoryProvider);
    ref.watch(transactionsProvider);
    ref.watch(customersProvider);

    final shell = Row(children: [
      AppSidebar(
        selectedIndex: idx,
        onItemSelected: (i) => ref.read(navigationIndexProvider.notifier).setIndex(i),
      ),
      Expanded(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            ref.read(sidebarCollapsedProvider.notifier).collapse();
            ref.read(pinUnlockProvider.notifier).recordActivity();
          },
          child: IndexedStack(index: idx, children: _pages),
        ),
      ),
    ]);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      resizeToAvoidBottomInset: false, // Prevent UI jumping on keyboard
      body: shell,
    );
  }
}
