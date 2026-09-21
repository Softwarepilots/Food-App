import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/menu/presentation/screens/menu_list_screen.dart';
import '../../features/orders/presentation/screens/order_list_screen.dart';
import '../../features/restaurant/presentation/providers/restaurant_provider.dart';
import '../../features/restaurant/presentation/screens/business_hours_screen.dart';
import '../../features/restaurant/presentation/screens/restaurant_settings_screen.dart';
import '../../features/restaurant/presentation/screens/restaurant_setup_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import 'main_shell.dart';
import 'route_paths.dart';

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
    ref.listen<AsyncValue<dynamic>>(myRestaurantProvider, (previous, next) {
      if (previous?.isLoading != next.isLoading || previous?.value != next.value) notifyListeners();
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
      final isAuthRoute = currentPath == RoutePaths.login || currentPath == RoutePaths.register;

      if (authState.status == AuthStatus.unknown) {
        return currentPath == RoutePaths.splash ? null : RoutePaths.splash;
      }
      if (authState.status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : RoutePaths.login;
      }

      // Authenticated — gate on whether a restaurant has been set up yet.
      // Uses valueOrNull (not value): AsyncValue.value rethrows the error
      // when the provider is in an AsyncError state, which would otherwise
      // crash routing on any transient fetch failure.
      final restaurantAsync = ref.read(myRestaurantProvider);
      if (restaurantAsync.isLoading) {
        return currentPath == RoutePaths.splash ? null : RoutePaths.splash;
      }
      final hasRestaurant = restaurantAsync.valueOrNull != null;
      if (!hasRestaurant) {
        return currentPath == RoutePaths.setup ? null : RoutePaths.setup;
      }
      if (currentPath == RoutePaths.splash || isAuthRoute || currentPath == RoutePaths.setup) {
        return RoutePaths.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: RoutePaths.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: RoutePaths.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: RoutePaths.setup, builder: (context, state) => const RestaurantSetupScreen()),
      GoRoute(
        path: RoutePaths.businessHours,
        builder: (context, state) => BusinessHoursScreen(restaurantId: state.extra as String),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.dashboard, builder: (context, state) => const DashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.orders, builder: (context, state) => const OrderListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.menu, builder: (context, state) => const MenuListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.settings, builder: (context, state) => const RestaurantSettingsScreen())]),
        ],
      ),
    ],
  );
});
