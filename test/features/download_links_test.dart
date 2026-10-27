import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/core/config/app_contacts.dart';
import 'package:buildera/features/subscription/models/entitlement.dart';
import 'package:buildera/features/subscription/providers/subscription_provider.dart';
import 'package:buildera/features/products/presentation/widgets/excel_import_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tahap 3: Download Links Tests', () {
    test('AppContacts.isConfigured validates URLs correctly', () {
      expect(AppContacts.isConfigured(''), isFalse);
      expect(AppContacts.isConfigured('   '), isFalse);
      expect(AppContacts.isConfigured('ftp://invalid.com'), isFalse);
      expect(AppContacts.isConfigured('http://example.com/file.pdf'), isTrue);
      expect(AppContacts.isConfigured('https://github.com/file.xlsx'), isTrue);
    });

    testWidgets('ExcelImportDialog renders Unduh Format Excel button when configured', (tester) async {
      tester.view.physicalSize = const Size(800, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final container = ProviderContainer(
        overrides: [
          entitlementProvider.overrideWith(() => EntitlementNotifierMock(
            Entitlement.premium(
              validUntil: DateTime.now().add(const Duration(days: 30)),
              source: EntitlementSource.play,
            ),
          )),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ExcelImportDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      if (AppContacts.isConfigured(AppContacts.excelImportTemplateUrl)) {
        expect(find.text('Format Excel'), findsOneWidget);
        expect(find.text('Gunakan format ini agar impor berhasil.'), findsOneWidget);
      } else {
        expect(find.text('Format Excel'), findsNothing);
      }
    });
  });
}

class EntitlementNotifierMock extends EntitlementNotifier {
  final Entitlement initial;
  EntitlementNotifierMock(this.initial);

  @override
  Entitlement build() => initial;
}
