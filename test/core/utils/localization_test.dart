import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/core/localization/app_language.dart';
import 'package:buildera/core/localization/app_strings.dart';

void main() {
  group('Localization Tests', () {
    test('AppLanguage.fromCode parses language codes accurately', () {
      expect(AppLanguage.fromCode('en'), equals(AppLanguage.english));
      expect(AppLanguage.fromCode('id'), equals(AppLanguage.indonesian));
      expect(AppLanguage.fromCode(null), equals(AppLanguage.indonesian));
      expect(AppLanguage.fromCode('fr'), equals(AppLanguage.indonesian));
    });

    test('AppLanguage properties code, displayName, flag are valid', () {
      expect(AppLanguage.english.code, equals('en'));
      expect(AppLanguage.english.displayName, equals('English'));
      expect(AppLanguage.english.flag, equals('🇺🇸'));

      expect(AppLanguage.indonesian.code, equals('id'));
      expect(AppLanguage.indonesian.displayName, equals('Bahasa Indonesia'));
      expect(AppLanguage.indonesian.flag, equals('🇮🇩'));
    });

    test('AppStrings resolves Indonesian string labels', () {
      const strings = AppStrings(AppLanguage.indonesian);
      expect(strings.isEnglish, isFalse);
      expect(strings.navCashier, equals('Kasir'));
      expect(strings.navProducts, equals('Produk'));
      expect(strings.navTransactions, equals('Transaksi'));
      expect(strings.navDebts, equals('Piutang'));
      expect(strings.navSettings, equals('Pengaturan'));
      expect(strings.processPayment, equals('Proses Pembayaran'));
      expect(strings.cash, equals('Tunai'));
    });

    test('AppStrings resolves English string labels', () {
      const strings = AppStrings(AppLanguage.english);
      expect(strings.isEnglish, isTrue);
      expect(strings.navCashier, equals('Cashier'));
      expect(strings.navProducts, equals('Products'));
      expect(strings.navTransactions, equals('Transactions'));
      expect(strings.navDebts, equals('Receivables'));
      expect(strings.navSettings, equals('Settings'));
      expect(strings.processPayment, equals('Process Payment'));
      expect(strings.cash, equals('Cash'));
    });
  });
}
