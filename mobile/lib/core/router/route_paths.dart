class RoutePaths {
  RoutePaths._();

  static const String splash = '/splash';
  static const String phoneEntry = '/phone-entry';
  static const String otpVerify = '/otp-verify';

  static const String home = '/home';
  static const String orders = '/orders';
  static const String cart = '/cart';
  static const String profile = '/profile';

  static const String restaurants = '/restaurants';
  static String restaurantDetail(String id) => '/restaurants/$id';
  static const String foodDetails = '/food-details';

  static const String checkout = '/checkout';
  static const String addAddress = '/checkout/add-address';

  static String orderDetail(String id) => '/orders/$id';

  static const String editProfile = '/profile/edit';
  static const String addressList = '/profile/addresses';
  static const String favorites = '/favorites';
}
