import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/restaurant_repository_provider.dart';
import '../widgets/restaurant_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Favorites')),
      body: favoritesAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          failure: Failure.fromException(error),
          onRetry: () => ref.invalidate(favoritesProvider),
        ),
        data: (restaurants) {
          if (restaurants.isEmpty) {
            return const EmptyView(
              title: 'No favorites yet',
              message: 'Tap the heart on any restaurant to save it here.',
              icon: Icons.favorite_border,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(favoritesProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: restaurants.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final restaurant = restaurants[index];
                return RestaurantCard(
                  restaurant: restaurant,
                  onTap: () => context.push('/restaurants/${restaurant.id}'),
                  onFavoriteToggle: () async {
                    await ref.read(restaurantRepositoryProvider).setFavorite(restaurant.id, false);
                    ref.invalidate(favoritesProvider);
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
