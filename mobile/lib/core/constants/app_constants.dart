class AppConstants {
  AppConstants._();

  static const String appName = 'Garuda';
  static const String appTagline = 'Good Food. Fast. For You.';
  static const String cityTagline = 'Karaikal First. Always.';
  static const int defaultPageSize = 20;
  static const double defaultSearchRadiusKm = 10;
  static const Duration searchDebounce = Duration(milliseconds: 400);
  static const Duration orderPollInterval = Duration(seconds: 15);
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';
  static const int otpLength = 6;
}
