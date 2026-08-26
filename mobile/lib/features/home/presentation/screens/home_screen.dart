import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../restaurants/presentation/providers/restaurant_list_provider.dart';
import '../../../restaurants/presentation/providers/restaurant_repository_provider.dart';
import '../../../restaurants/presentation/widgets/restaurant_card.dart';
import '../widgets/category_chip_list.dart';
import '../widgets/promo_banner_carousel.dart';
import '../widgets/quick_action_row.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final categoriesAsync = ref.watch(restaurantCategoriesProvider);
    final listState = ref.watch(restaurantListProvider);
    final firstName = authState.user?.fullName.split(' ').first ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(restaurantCategoriesProvider);
            await ref.read(restaurantListProvider.notifier).refresh();
          },
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => context.push('/profile'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: AppColors.primary, size: 20),
                            const SizedBox(width: 4),
                            Text('Karaikal', style: AppTextStyles.titleMedium),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: AppColors.chipBackground, shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No new notifications')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text('Hey $firstName, ${AppConstants.appTagline.toLowerCase()}', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: InkWell(
                    onTap: () => context.push('/restaurants'),
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Text('Search restaurants or cuisines', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                  child: PromoBannerCarousel(),
                ),
              ),
              SliverToBoxAdapter(
                child: QuickActionRow(
                  onFastDelivery: () => context.push('/restaurants'),
                  onNearMe: () => context.push('/restaurants'),
                  onPopular: () => context.push('/restaurants'),
                  onOffers: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Offers are coming soon to Garuda')),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('Categories', style: AppTextStyles.titleLarge),
                ),
              ),
              SliverToBoxAdapter(
                child: categoriesAsync.when(
                  loading: () => const SizedBox(height: 96, child: LoadingIndicator(size: 24)),
                  error: (error, _) => const SizedBox.shrink(),
                  data: (categories) => CategoryChipList(
                    categories: categories,
                    onTap: (category) => context.push('/restaurants', extra: {'initialCategory': category.id}),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Top Restaurants', style: AppTextStyles.titleLarge),
                      TextButton(
                        onPressed: () => context.push('/restaurants'),
                        child: Text('See all', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary)),
                      ),
                    ],
                  ),
                ),
              ),
              _buildRestaurantsSliver(listState, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantsSliver(RestaurantListState state, WidgetRef ref) {
    if (state.isLoading && state.restaurants.isEmpty) {
      return const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(32), child: LoadingIndicator()));
    }
    if (state.failure != null && state.restaurants.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorView(failure: state.failure!, onRetry: () => ref.read(restaurantListProvider.notifier).refresh()),
        ),
      );
    }
    if (state.restaurants.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No restaurants found near you yet.'))),
      );
    }

    final restaurants = state.restaurants.take(8).toList();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverList.separated(
        itemCount: restaurants.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];
          return RestaurantCard(
            restaurant: restaurant,
            onTap: () => context.push('/restaurants/${restaurant.id}'),
            onFavoriteToggle: () => ref.read(restaurantListProvider.notifier).toggleFavorite(restaurant.id),
          );
        },
      ),
    );
  }
}
