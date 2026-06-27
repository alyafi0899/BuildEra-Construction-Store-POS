import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currency = NumberFormat.currency(
    locale:        'id_ID',
    symbol:        'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _decimal = NumberFormat('#,##0.##', 'id_ID');
  static final DateFormat   _date    = DateFormat('dd/MM/yyyy', 'id_ID');
  static final DateFormat   _dateTime = DateFormat('dd/MM/yyyy HH:mm', 'id_ID');

  static String currency(double v) => _currency.format(v);
  static String decimal(double v)  => _decimal.format(v);
  static String date(DateTime d)   => _date.format(d);
  static String dateTime(DateTime d) => _dateTime.format(d);

  static String month(int month) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month];
  }

  static double parseDecimal(String s) {
    final clean = s.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(clean) ?? 0;
  }
}
