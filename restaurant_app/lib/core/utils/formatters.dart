import 'package:intl/intl.dart';
import '../constants/app_constants.dart';

class Formatters {
  Formatters._();

  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: AppConstants.currencySymbol,
    decimalDigits: 2,
  );

  static String currency(num amount) => _currencyFormat.format(amount);

  static String date(DateTime dateTime) => DateFormat('d MMM yyyy').format(dateTime.toLocal());

  static String time(DateTime dateTime) => DateFormat('h:mm a').format(dateTime.toLocal());

  static String dateTime(DateTime dateTime) => DateFormat('d MMM yyyy, h:mm a').format(dateTime.toLocal());

  static String relative(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final diff = now.difference(local);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(local);
  }

  static String distanceKm(double km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1)} km';
  }
}
