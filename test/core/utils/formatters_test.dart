import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:buildera/core/utils/formatters.dart';

void main() {
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
