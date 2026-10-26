import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:buildera/features/auth/models/auth_user.dart';
import 'package:buildera/features/auth/providers/auth_provider.dart';
import 'package:buildera/features/settings/models/store_settings.dart';
import 'package:buildera/features/settings/providers/settings_provider.dart';
import 'package:buildera/features/auth/presentation/pages/setup_pin_page.dart';

class _UnloadedSettingsNotifier extends SettingsLoadedNotifier {
  @override
  bool build() => false;
}

class _MockAuthNotifier extends AuthNotifier {
  final AuthUser? user;
  _MockAuthNotifier(this.user);

  @override
  Stream<AuthUser?> build() => Stream.value(user);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tahap 1: Auth & Settings Stability Tests', () {
    test('AuthUser operator == and hashCode equality based on fields', () {
      const user1 = AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        isEmailVerified: true,
        displayName: 'Toko Budi',
      );
      const user2 = AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        isEmailVerified: true,
        displayName: 'Toko Budi',
      );
      const user3 = AuthUser(
        uid: 'user-123',
        email: 'test@example.com',
        isEmailVerified: false,
        displayName: 'Toko Budi',
      );

      expect(user1 == user2, isTrue);
      expect(user1.hashCode, equals(user2.hashCode));

      expect(user1 == user3, isFalse);
      expect(user1.hashCode, isNot(equals(user3.hashCode)));
    });

    test('Identical AuthUser emission does not reset loaded settings state', () async {
      const user = AuthUser(
        uid: 'uid-1',
        email: 'test@example.com',
        isEmailVerified: true,
      );

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(() => _MockAuthNotifier(user)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(settingsProvider.notifier);

      // Simulate completed settings load
      const loadedSettings = StoreSettings(
        businessName: 'Toko Bangunan Sejahtera',
        securityPin: '1234',
        isLoading: false,
      );
      
      notifier.applyTestSettings('uid-1', loadedSettings);

      expect(container.read(settingsLoadedProvider), isTrue);
      expect(container.read(settingsProvider).securityPin, equals('1234'));
      expect(container.read(settingsProvider).businessName, equals('Toko Bangunan Sejahtera'));

      // Re-run build for the same UID
      final result = notifier.build();

      expect(result.securityPin, equals('1234'));
      expect(result.businessName, equals('Toko Bangunan Sejahtera'));
      expect(container.read(settingsLoadedProvider), isTrue);
    });

    testWidgets('SetupPinPage rejects _savePin when settings are not loaded', (tester) async {
      tester.view.physicalSize = const Size(1000, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const user = AuthUser(
        uid: 'uid-1',
        email: 'test@example.com',
        isEmailVerified: true,
      );

      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(() => _MockAuthNotifier(user)),
          settingsLoadedProvider.overrideWith(_UnloadedSettingsNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SetupPinPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter PIN 1234
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '1234');
      await tester.enterText(textFields.at(1), '1234');

      // Tap Save
      await tester.tap(find.text('SIMPAN & LANJUT'));
      await tester.pumpAndSettle();

      // Should display error message
      expect(find.text('Pengaturan belum termuat, coba lagi sebentar'), findsOneWidget);
    });
  });
}
