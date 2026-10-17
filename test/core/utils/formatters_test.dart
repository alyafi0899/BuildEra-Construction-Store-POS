import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:buildera/core/utils/formatters.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('Formatters Static Helpers', () {
    test('Formatters.currency formats numbers with Rp prefix and thousands separator', () {
      expect(Formatters.currency(100000), contains('100.000'));
      expect(Formatters.currency(0), contains('0'));
    });

    test('Formatters.decimal formats decimal numbers according to id_ID locale', () {
      expect(Formatters.decimal(1234.56), equals('1.234,56'));
      expect(Formatters.decimal(50), equals('50'));
    });

    test('Formatters.date and dateTime format DateTime objects', () {
      final date = DateTime(2026, 10, 17, 14, 30);
      expect(Formatters.date(date), equals('17/10/2026'));
      expect(Formatters.dateTime(date), equals('17/10/2026 14:30'));
    });

    test('Formatters.month converts month index to Indonesian month name', () {
      expect(Formatters.month(1), equals('Januari'));
      expect(Formatters.month(8), equals('Agustus'));
      expect(Formatters.month(12), equals('Desember'));
    });

    test('Formatters.parsePrice parses thousands separator dot and decimal comma', () {
      expect(Formatters.parsePrice('100.000'), equals(100000.0));
      expect(Formatters.parsePrice('1.500.000,50'), equals(1500000.50));
      expect(Formatters.parsePrice(''), equals(0.0));
    });

    test('Formatters.parseQuantity converts comma decimal to dot decimal', () {
      expect(Formatters.parseQuantity('1,5'), equals(1.5));
      expect(Formatters.parseQuantity('0.25'), equals(0.25));
      expect(Formatters.parseQuantity(''), equals(0.0));
    });
  });

  group('CurrencyInputFormatter', () {
    test('formats digits with thousands separators', () {
      final formatter = CurrencyInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(
          text: '1000',
          selection: TextSelection.collapsed(offset: 4),
        ),
      );

      expect(result.text, '1.000');
    });

    test('keeps the caret position stable while typing', () {
      final formatter = CurrencyInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
            text: '12', selection: TextSelection.collapsed(offset: 2)),
        const TextEditingValue(
            text: '1234', selection: TextSelection.collapsed(offset: 3)),
      );

      expect(result.text, '1.234');
      expect(result.selection.baseOffset, 4);
    });
  });
}
