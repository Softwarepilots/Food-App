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

  // Auth (email + password — delivery partners onboard via a vehicle/license
  // form, not the customer app's phone+OTP flow)
  static const String register = '/auth/register/';
  static const String login = '/auth/login/';
  static const String tokenRefresh = '/auth/token/refresh/';
  static const String logout = '/auth/logout/';
  static const String me = '/auth/me/';

  // Delivery partner profile + availability
  static const String partnerProfile = '/delivery/partners/me/';
  static const String partnerStatus = '/delivery/partners/me/status/';

  // Orders
  static const String availableOrders = '/delivery/orders/available/';
  static const String myDeliveries = '/delivery/orders/mine/';
  static String acceptOrder(String orderId) => '/delivery/orders/$orderId/accept/';
  static String deliverOrder(String orderId) => '/delivery/orders/$orderId/deliver/';

  // Notifications
  static const String deviceRegister = '/notifications/devices/register/';
  static const String deviceUnregister = '/notifications/devices/unregister/';

  // Gigs (bookable shifts)
  static const String shifts = '/delivery/shifts/';
  static const String myShifts = '/delivery/shifts/mine/';
  static String bookShift(String shiftId) => '/delivery/shifts/$shiftId/book/';
  static String cancelShift(String shiftId) => '/delivery/shifts/$shiftId/cancel/';
}
