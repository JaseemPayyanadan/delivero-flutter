import 'package:intl/intl.dart';

String formatRupee(double amount) {
  final whole = amount == amount.roundToDouble();
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: whole ? 0 : 2,
  ).format(amount);
}
