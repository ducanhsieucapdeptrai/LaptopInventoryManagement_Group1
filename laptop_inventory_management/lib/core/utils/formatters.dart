import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final DateFormat _dateOnlyFormat = DateFormat('dd/MM/yyyy');

  static String formatCurrency(num amount) {
    return _currencyFormat.format(amount);
  }

  static String formatDateTime(DateTime dateTime) {
    return _dateFormat.format(dateTime.toLocal());
  }

  static String formatDate(DateTime dateTime) {
    return _dateOnlyFormat.format(dateTime.toLocal());
  }

  static String formatIsoDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoString);
      return formatDateTime(dt);
    } catch (_) {
      return isoString;
    }
  }
}
