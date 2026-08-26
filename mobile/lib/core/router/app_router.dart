import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/otp_verify_screen.dart';
import '../../features/auth/presentation/screens/phone_entry_screen.dart';
import '../../features/cart/presentation/screens/cart_screen.dart';
import '../../features/checkout/presentation/screens/add_address_screen.dart';
import '../../features/checkout/presentation/screens/checkout_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/menu/data/models/food_model.dart';
import '../../features/menu/presentation/screens/food_details_screen.dart';
import '../../features/orders/presentation/screens/order_detail_screen.dart';
import '../../features/orders/presentation/screens/order_list_screen.dart';
import '../../features/profile/presentation/screens/address_list_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/restaurants/presentation/screens/favorites_screen.dart';
import '../../features/restaurants/presentation/screens/restaurant_detail_screen.dart';
import '../../features/restaurants/presentation/screens/restaurant_list_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import 'main_shell.dart';
import 'route_paths.dart';

/// Bridges Riverpod's [authProvider] state changes into a [Listenable] so
/// [GoRouter]'s `refreshListenable` re-evaluates `redirect` whenever auth
/// status changes (login, logout, or session expiry).
class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = GoRouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final currentPath = state.matchedLocation;
      final isAuthRoute = currentPath == RoutePaths.phoneEntry || currentPath == RoutePaths.otpVerify;

      if (authState.status == AuthStatus.unknown) {
        return currentPath == RoutePaths.splash ? null : RoutePaths.splash;
      }
      if (authState.status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : RoutePaths.phoneEntry;
      }
      // Authenticated.
      if (currentPath == RoutePaths.splash || isAuthRoute) {
        return RoutePaths.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: RoutePaths.phoneEntry, builder: (context, state) => const PhoneEntryScreen()),
      GoRoute(
        path: RoutePaths.otpVerify,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return OtpVerifyScreen(
            phoneNumber: extra['phoneNumber'] as String,
            isNewUser: extra['isNewUser'] as bool,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.home, builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.orders, builder: (context, state) => const OrderListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.cart, builder: (context, state) => const CartScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: RoutePaths.profile, builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: RoutePaths.restaurants,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RestaurantListScreen(
            initialSearch: extra?['initialSearch'] as String?,
            initialCategory: extra?['initialCategory'] as String?,
          );
        },
      ),
      GoRoute(
        path: '${RoutePaths.restaurants}/:id',
        builder: (context, state) => RestaurantDetailScreen(restaurantId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: RoutePaths.foodDetails,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return FoodDetailsScreen(
            food: extra['food'] as FoodModel,
            restaurantId: extra['restaurantId'] as String,
            restaurantName: extra['restaurantName'] as String,
          );
        },
      ),
      GoRoute(path: RoutePaths.checkout, builder: (context, state) => const CheckoutScreen()),
      GoRoute(path: RoutePaths.addAddress, builder: (context, state) => const AddAddressScreen()),
      GoRoute(
        path: '${RoutePaths.orders}/:id',
        builder: (context, state) => OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: RoutePaths.editProfile, builder: (context, state) => const EditProfileScreen()),
      GoRoute(path: RoutePaths.addressList, builder: (context, state) => const AddressListScreen()),
      GoRoute(path: RoutePaths.favorites, builder: (context, state) => const FavoritesScreen()),
    ],
  );
});
