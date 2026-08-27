import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_home_screen.dart';
import '../../features/delivery_partners/presentation/screens/delivery_partners_screen.dart';
import '../../features/orders/presentation/screens/orders_screen.dart';
import '../../features/restaurants/presentation/screens/restaurants_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/users/presentation/screens/users_screen.dart';
import 'main_shell.dart';
import 'route_paths.dart';

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
      final isAuthRoute = currentPath == RoutePaths.login;

      if (authState.status == AuthStatus.unknown) {
        return currentPath == RoutePaths.splash ? null : RoutePaths.splash;
      }
      if (authState.status == AuthStatus.unauthenticated) {
        return isAuthRoute ? null : RoutePaths.login;
      }

      // Authenticated — the role check already happened inside login(), so
      // by the time we reach AuthStatus.authenticated the user is an admin.
      if (currentPath == RoutePaths.splash || isAuthRoute) {
        return RoutePaths.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: RoutePaths.login, builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.dashboard, builder: (context, state) => const DashboardHomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.restaurants, builder: (context, state) => const RestaurantsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.users, builder: (context, state) => const UsersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.deliveryPartners, builder: (context, state) => const DeliveryPartnersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.orders, builder: (context, state) => const OrdersScreen())]),
        ],
      ),
    ],
  );
});
