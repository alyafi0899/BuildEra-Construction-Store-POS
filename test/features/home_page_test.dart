import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:buildera/core/providers/navigation_provider.dart';
import 'package:buildera/features/home/presentation/pages/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('Tahap 5: HomePage & Navigation Tests', () {
    test('Default initial page index is home (12)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(navigationIndexProvider), equals(AppPageIndices.home));
      expect(AppPageIndices.home, equals(12));
      expect(AppPageIndices.cashier, equals(0));
    });

    testWidgets('HomePage renders store title and feature grid', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: HomePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Selamat Datang,'), findsOneWidget);
      expect(find.text('Daftar Fitur Toko'), findsOneWidget);
      expect(find.text('Kasir POS'), findsOneWidget);
      expect(find.text('Produk & Stok'), findsOneWidget);
      expect(find.text('Pengaturan'), findsOneWidget);
    });
  });
}
