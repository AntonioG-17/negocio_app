import 'package:intl/intl.dart';

final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);
final _currencyDecimal = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
final _dateShort = DateFormat('dd/MM/yyyy');
final _dateTime = DateFormat('dd/MM/yyyy HH:mm');
final _timeOnly = DateFormat('HH:mm');
final _monthYear = DateFormat('MMMM yyyy', 'es');

String formatCurrency(double amount) {
  if (amount.isNaN || amount.isInfinite) return '\$0';
  return _currency.format(amount);
}

String formatCurrencyDecimal(double amount) {
  if (amount.isNaN || amount.isInfinite) return '\$0.00';
  return _currencyDecimal.format(amount);
}

String formatDate(DateTime date) => _dateShort.format(date);
String formatDateTime(DateTime date) => _dateTime.format(date);
String formatTime(DateTime date) => _timeOnly.format(date);
String formatMonthYear(DateTime date) => _monthYear.format(date);

String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inDays == 0) return 'Hoy';
  if (diff.inDays == 1) return 'Ayer';
  if (diff.inDays < 7) return 'Hace ${diff.inDays} dias';
  return formatDate(date);
}
