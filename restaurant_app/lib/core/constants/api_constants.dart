import 'package:flutter/foundation.dart' show kIsWeb;

/// API configuration. Override the base URL per build via:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
class ApiConstants {
  ApiConstants._();

  static const String _baseUrlOverride = String.fromEnvironment('API_BASE_URL');

  // 10.0.2.2 is the Android emulator's alias for the host machine's localhost;
  // it doesn't resolve on web (Chrome) or a real device, so pick per-platform.
  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    return kIsWeb ? 'http://localhost:8000/api/v1' : 'http://10.0.2.2:8000/api/v1';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  // Auth (email + password — restaurant partners onboard via a business form,
  // not the customer app's phone+OTP flow)
  static const String register = '/auth/register/';
  static const String login = '/auth/login/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/auth/me/';

  // Restaurants (owner-scoped)
  static const String restaurants = '/restaurants/';
  static const String myRestaurants = '/restaurants/mine/';
  static String restaurantDetail(String id) => '/restaurants/$id/';
  static String restaurantStatus(String id) => '/restaurants/$id/status/';
  static String restaurantBusinessHours(String id) => '/restaurants/$id/business-hours/';

  // Menu (owner-scoped)
  static String foods(String restaurantId) => '/menu/restaurants/$restaurantId/foods/';
  static String foodDetail(String restaurantId, String foodId) => '/menu/restaurants/$restaurantId/foods/$foodId/';
  static String foodAvailability(String restaurantId, String foodId) =>
      '/menu/restaurants/$restaurantId/foods/$foodId/availability/';

  // Orders (owner-scoped)
  static const String restaurantOrders = '/orders/restaurant-orders/';
  static String orderStatus(String id) => '/orders/$id/status/';
}
