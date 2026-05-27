// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'data/hive/hive_service.dart';
import 'app_shell.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  // Initialize Hive (works on web + desktop)
  await HiveService.init();

  // Seed dummy data on first launch
  await HiveService.seed();
  runApp(
    const ProviderScope(
      child: KonstrukPOSApp(),
    ),
  );
}

class KonstrukPOSApp extends StatelessWidget {
  const KonstrukPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adi Jaya Cashier',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}
