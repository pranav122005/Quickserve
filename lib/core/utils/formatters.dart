import 'package:intl/intl.dart';

class Formatters {
  static final DateFormat _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');
  static final DateFormat _timeFormat = DateFormat('hh:mm a');

  static String formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return _dateTimeFormat.format(dateTime.toLocal());
  }

  static String formatDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return _dateFormat.format(dateTime.toLocal());
  }

  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';
    return _timeFormat.format(dateTime.toLocal());
  }

  static String formatCurrency(double amount, {String currency = 'INR'}) {
    final symbol = currency == 'INR' ? '₹' : (currency == 'USD' ? '\$' : '$currency ');
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Formats a database request UUID into a human-readable unique identifier
  /// such as REQ-2026-000123.
  static String formatRequestId(String id, [DateTime? createdAt]) {
    if (id.isEmpty) return 'REQ-UNKNOWN';
    if (id.startsWith('REQ-')) return id;
    final year = (createdAt ?? DateTime.now()).year;
    final clean = id.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final suffix = clean.length >= 6 ? clean.substring(0, 6) : clean.padLeft(6, '0');
    return 'REQ-$year-$suffix';
  }
}
