// lib/core/utils/formatters.dart
import 'package:intl/intl.dart';

class AppFormatters {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final _numberFormat = NumberFormat('#,##0.##', 'id_ID');
  static final _dateFormat = DateFormat('dd/MM/yyyy', 'id_ID');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');
  static final _timeFormat = DateFormat('HH:mm', 'id_ID');

  static String formatCurrency(double amount) {
    return _currencyFormat.format(amount);
  }

  static String formatNumber(double number) {
    return _numberFormat.format(number);
  }

  static String formatDate(DateTime date) {
    return _dateFormat.format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateTimeFormat.format(dateTime);
  }

  static String formatTime(DateTime time) {
    return _timeFormat.format(time);
  }

  static String formatQuantity(double qty) {
    if (qty == qty.truncateToDouble()) {
      return qty.toInt().toString();
    }
    return _numberFormat.format(qty);
  }
}
