import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

class Formatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _decimal = NumberFormat('#,##0.##', 'id_ID');
  static final DateFormat _date = DateFormat('dd/MM/yyyy', 'id_ID');
  static final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');

  static String currency(double v) => _currency.format(v);
  static String decimal(double v) => _decimal.format(v);
  static String date(DateTime d) => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);

  static String month(int month) {
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember'
    ];
    return months[month];
  }

  static double parseDecimal(String s) {
    final clean = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0;
  }
}

/// A formatter that adds thousands separators (dots) while typing.
/// Used for nominal inputs like prices and payments.
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final value = int.tryParse(digitsOnly);
    if (value == null) {
      return oldValue;
    }

    final formattedText = NumberFormat.decimalPattern('id_ID').format(value);

    final selectionOffset =
        newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final rawBeforeCursor = newValue.text.substring(0, selectionOffset);
    final digitsBeforeCursor =
        rawBeforeCursor.replaceAll(RegExp(r'\D'), '').length;
    final cursorOffset =
        _cursorOffsetForDigitIndex(formattedText, digitsBeforeCursor);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }

  int _cursorOffsetForDigitIndex(String text, int digitIndex) {
    if (digitIndex <= 0) return 0;

    var digitsSeen = 0;
    for (var i = 0; i < text.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(text[i])) {
        digitsSeen++;
        if (digitsSeen == digitIndex) {
          return i + 1;
        }
      }
    }

    return text.length;
  }
}
