/// API configuration. Override the base URL per build via:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
  static const Duration sendTimeout = Duration(seconds: 20);

  // Auth
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/auth/me/';
  static const String otpRequest = '/auth/otp/request/';
  static const String otpVerify = '/auth/otp/verify/';

  // Restaurants
  static const String restaurants = '/restaurants/';
  static const String restaurantCategories = '/restaurants/categories/';
  static const String favorites = '/restaurants/favorites/';
  static String restaurantDetail(String id) => '/restaurants/$id/';
  static String restaurantRatings(String id) => '/restaurants/$id/ratings/';
  static String restaurantFavorite(String id) => '/restaurants/$id/favorite/';

  // Menu
  static String publicMenu(String restaurantId) => '/menu/restaurants/$restaurantId/menu/';
  static String foodReviews(String foodId) => '/menu/foods/$foodId/reviews/';

  // Addresses (accounts app, mounted under /auth/)
  static const String addresses = '/auth/addresses/';
  static String addressDetail(String id) => '/auth/addresses/$id/';

  // Orders
  static const String orders = '/orders/';
  static String orderDetail(String id) => '/orders/$id/';
  static String orderStatus(String id) => '/orders/$id/status/';
  static String orderCancel(String id) => '/orders/$id/cancel/';

  // Payments
  static const String paymentVerify = '/payments/razorpay/verify/';
}
