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
import 'features/settings/providers/app_settings_provider.dart';
import 'features/cashier/presentation/pages/customer_display_page.dart';
import 'features/cashier/providers/customer_display_provider.dart';
import 'features/cashier/providers/cart_provider.dart';
import 'features/cashier/providers/scan_mode_provider.dart';
import 'features/cashier/presentation/widgets/barcode_listener.dart';
import 'features/products/providers/product_provider.dart';
import 'features/auth/presentation/widgets/auth_gate.dart';
import 'core/sync/services/local_database.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'shared/widgets/splash_screen.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Check for multi-window arguments immediately
  if (args.isNotEmpty && args.first == 'multi_window') {
    await LocalDatabase.init();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await initializeDateFormatting('id_ID', null);
    runApp(ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const CustomerDisplayPage(),
      ),
    ));
    return;
  }

  // 2. Main Window setup
  await LocalDatabase.init();

  // Show splash screen immediately
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SplashScreen(),
  ));

  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(1280, 800),
      center: true,
      backgroundColor: Color(0xFF0F1117),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    if (!kIsWeb && Platform.isWindows) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    }

    await initializeDateFormatting('id_ID', null);

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
      title: 'Konstruksi POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AuthGate(), // Root logic moved to AuthGate
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
    const AnalyticsPage(),
    const SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    ref.listenManual(cartProvider, (prev, next) {
      final settings = ref.read(appSettingsProvider);
      if (settings.isCustomerDisplayEnabled) {
        CustomerDisplayBridge.broadcastCart(next);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(productsProvider);

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
