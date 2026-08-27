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

  // Auth — admin accounts cannot self-register; they're provisioned directly
  // in the database/Django admin, then log in here with email + password.
  static const String login = '/auth/login/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/auth/me/';

  // Dashboard
  static const String dashboardStats = '/dashboard/stats/';

  // Users
  static const String adminUsers = '/auth/admin/users/';
  static String adminUserStatus(String userId) => '/auth/admin/users/$userId/status/';

  // Restaurants
  static const String adminRestaurants = '/restaurants/admin/all/';
  static const String pendingApprovalRestaurants = '/restaurants/pending-approval/';
  static String approveRestaurant(String restaurantId) => '/restaurants/$restaurantId/approve/';
  static String rejectRestaurant(String restaurantId) => '/restaurants/$restaurantId/reject/';

  // Delivery partners
  static const String adminDeliveryPartners = '/delivery/admin/partners/';
  static String verifyDeliveryPartner(String partnerId) => '/delivery/admin/partners/$partnerId/verify/';

  // Orders
  static const String adminOrders = '/orders/admin/all/';
}
