import 'package:intl/intl.dart';

final NumberFormat _inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

String formatInr(num value) => _inrFormat.format(value);
