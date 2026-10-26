import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/gigs/presentation/screens/gigs_screen.dart';
import '../../features/orders/presentation/screens/available_orders_screen.dart';
import '../../features/orders/presentation/screens/my_deliveries_screen.dart';
import '../../features/profile/presentation/providers/partner_provider.dart';
import '../../features/profile/presentation/screens/partner_setup_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import 'main_shell.dart';
import 'route_paths.dart';

class GoRouterRefreshNotifier extends ChangeNotifier {
  GoRouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != next.status) notifyListeners();
    });
    ref.listen<AsyncValue<dynamic>>(myPartnerProfileProvider, (previous, next) {
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

      // Authenticated — gate on whether a delivery partner profile has been
      // set up yet. Uses valueOrNull (not value): AsyncValue.value rethrows
      // the error when the provider is in an AsyncError state, which would
      // otherwise crash routing on any transient fetch failure.
      final profileAsync = ref.read(myPartnerProfileProvider);
      if (profileAsync.isLoading) {
        return currentPath == RoutePaths.splash ? null : RoutePaths.splash;
      }
      final hasProfile = profileAsync.valueOrNull != null;
      if (!hasProfile) {
        return currentPath == RoutePaths.setup ? null : RoutePaths.setup;
      }
      if (currentPath == RoutePaths.splash || isAuthRoute || currentPath == RoutePaths.setup) {
        return RoutePaths.available;
      }
      return null;
    },
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(path: RoutePaths.login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: RoutePaths.register, builder: (context, state) => const RegisterScreen()),
      GoRoute(path: RoutePaths.setup, builder: (context, state) => const PartnerSetupScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.available, builder: (context, state) => const AvailableOrdersScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.gigs, builder: (context, state) => const GigsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.deliveries, builder: (context, state) => const MyDeliveriesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: RoutePaths.profile, builder: (context, state) => const ProfileScreen())]),
        ],
      ),
    ],
  );
});
