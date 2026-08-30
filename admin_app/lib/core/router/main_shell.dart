import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../theme/app_colors.dart';

/// Desktop-web dashboard chrome: a persistent left [NavigationRail] rather
/// than restaurant_app's bottom [NavigationBar] — this app is viewed in a
/// wide browser window, not a phone.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
            backgroundColor: AppColors.surface,
            labelType: NavigationRailLabelType.all,
            leading: const SizedBox(height: 12),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    tooltip: 'Log out',
                    icon: const Icon(Icons.logout, color: AppColors.textSecondary),
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront),
                label: Text('Restaurants'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Users'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.two_wheeler_outlined),
                selectedIcon: Icon(Icons.two_wheeler),
                label: Text('Delivery'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: Text('Orders'),
              ),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.divider),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}
