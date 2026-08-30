import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../menu/data/models/food_model.dart';
import '../../../menu/presentation/providers/menu_provider.dart';
import '../../../menu/presentation/widgets/food_list_tile.dart';
import '../../data/models/restaurant_model.dart';
import '../providers/restaurant_detail_provider.dart';
import '../providers/restaurant_repository_provider.dart';
import '../widgets/rating_badge.dart';

class RestaurantDetailScreen extends ConsumerWidget {
  final String restaurantId;

  const RestaurantDetailScreen({super.key, required this.restaurantId});

  void _onFoodTap(BuildContext context, RestaurantModel restaurant, FoodModel food) {
    context.push(
      '/food-details',
      extra: {
        'food': food,
        'restaurantId': restaurant.id,
        'restaurantName': restaurant.name,
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(restaurantDetailProvider(restaurantId));
    final cart = ref.watch(cartProvider);
    final showCartBar = !(cart.isEmpty || cart.restaurantId != restaurantId);

    return Scaffold(
      body: detailAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          failure: Failure.fromException(error),
          onRetry: () => ref.invalidate(restaurantDetailProvider(restaurantId)),
        ),
        data: (restaurant) => _RestaurantDetailBody(
          restaurant: restaurant,
          onFoodTap: (food) => _onFoodTap(context, restaurant, food),
        ),
      ),
      bottomSheet: !showCartBar
          ? null
          : Material(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              color: AppColors.primary,
              child: InkWell(
                onTap: () => context.go('/cart'),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined, color: AppColors.secondary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            '${cart.itemCount} Item${cart.itemCount > 1 ? 's' : ''}  •  ${Formatters.currency(cart.subtotal)}',
                            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.secondary, borderRadius: BorderRadius.circular(24)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('View Cart', style: AppTextStyles.labelLarge.copyWith(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
                            const SizedBox(width: 4),
                            Icon(Icons.arrow_forward, color: AppColors.primaryDark, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _RestaurantDetailBody extends ConsumerStatefulWidget {
  final RestaurantModel restaurant;
  final void Function(FoodModel food) onFoodTap;

  const _RestaurantDetailBody({required this.restaurant, required this.onFoodTap});

  @override
  ConsumerState<_RestaurantDetailBody> createState() => _RestaurantDetailBodyState();
}

class _RestaurantDetailBodyState extends ConsumerState<_RestaurantDetailBody> {
  int _selectedTab = 0;
  late bool _isFavorite = widget.restaurant.isFavorite;

  Future<void> _toggleFavorite() async {
    final next = !_isFavorite;
    setState(() => _isFavorite = next);
    try {
      await ref.read(restaurantRepositoryProvider).setFavorite(widget.restaurant.id, next);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = !next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurant.id));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          flexibleSpace: FlexibleSpaceBar(
            background: AppNetworkImage(url: widget.restaurant.displayImageUrl, height: 200, width: double.infinity),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
              child: IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? AppColors.secondary : Colors.white,
                ),
                onPressed: _toggleFavorite,
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(widget.restaurant.name, style: AppTextStyles.headlineSmall)),
                    const SizedBox(width: 8),
                    RatingBadge(rating: widget.restaurant.averageRating),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.restaurant.cuisineTags.isNotEmpty ? widget.restaurant.cuisineTags.join(', ') : widget.restaurant.city,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text('${widget.restaurant.avgPrepTimeMinutes}-${widget.restaurant.avgPrepTimeMinutes + 10} min', style: AppTextStyles.bodySmall),
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.restaurant.addressLine ?? widget.restaurant.city,
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (!widget.restaurant.isOpen) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                    child: const Text(
                      'This restaurant is currently closed. You can browse the menu but cannot place an order.',
                      style: TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: Divider(color: AppColors.divider, height: 1)),
        menuAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.all(32), child: LoadingIndicator()),
          ),
          error: (error, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ErrorView(
                failure: Failure.fromException(error),
                onRetry: () => ref.invalidate(restaurantMenuProvider(widget.restaurant.id)),
              ),
            ),
          ),
          data: (menu) {
            if (menu.isEmpty) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('This restaurant has no menu items yet.')),
                ),
              );
            }

            final bestsellers = [
              ...menu.uncategorized,
              for (final category in menu.categories) ...category.foods,
            ].where((food) => food.isBestseller).toList();

            final recommended = menu.uncategorized.isNotEmpty
                ? menu.uncategorized
                : [for (final category in menu.categories) ...category.foods];

            final tabs = <_MenuTab>[
              _MenuTab('Recommended', recommended),
              if (bestsellers.isNotEmpty) _MenuTab('Bestsellers', bestsellers),
              for (final category in menu.categories) _MenuTab(category.name, category.foods),
            ];
            final selected = _selectedTab < tabs.length ? _selectedTab : 0;

            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: tabs.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 20),
                      itemBuilder: (context, index) {
                        final isSelected = index == selected;
                        return InkWell(
                          onTap: () => setState(() => _selectedTab = index),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                tabs[index].label,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                height: 3,
                                width: 28,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: Divider(color: AppColors.divider, height: 1)),
                if (tabs[selected].foods.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No items in this section yet.')),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: tabs[selected].foods.length,
                      separatorBuilder: (_, _) => const Divider(color: AppColors.divider, height: 1),
                      itemBuilder: (context, index) {
                        final food = tabs[selected].foods[index];
                        return FoodListTile(food: food, onTap: () => widget.onFoodTap(food));
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MenuTab {
  final String label;
  final List<FoodModel> foods;

  const _MenuTab(this.label, this.foods);
}
