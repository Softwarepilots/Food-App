import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../providers/restaurant_list_provider.dart';
import '../widgets/restaurant_card.dart';
import '../widgets/restaurant_sort_sheet.dart';

class RestaurantListScreen extends ConsumerStatefulWidget {
  final String? initialSearch;
  final String? initialCategory;

  const RestaurantListScreen({super.key, this.initialSearch, this.initialCategory});

  @override
  ConsumerState<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends ConsumerState<RestaurantListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _debouncer = Debouncer(delay: const Duration(milliseconds: 400));
  RestaurantSort _sort = RestaurantSort.relevance;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialSearch ?? '';
    _scrollController.addListener(_onScroll);
    if (widget.initialCategory != null) {
      Future.microtask(() {
        ref.read(restaurantListProvider.notifier).updateFilters(
              RestaurantListFilters(category: widget.initialCategory, search: widget.initialSearch),
            );
      });
    } else if (widget.initialSearch != null) {
      Future.microtask(() {
        ref.read(restaurantListProvider.notifier).updateFilters(RestaurantListFilters(search: widget.initialSearch));
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(restaurantListProvider.notifier).loadNextPage();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restaurantListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Restaurants')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search restaurants or cuisines',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(restaurantListProvider.notifier).updateFilters(
                                state.filters.copyWith(search: ''),
                              );
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {});
                _debouncer.call(() {
                  ref.read(restaurantListProvider.notifier).updateFilters(state.filters.copyWith(search: value));
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Open now'),
                  selected: state.filters.onlyOpen,
                  onSelected: (selected) {
                    ref.read(restaurantListProvider.notifier).updateFilters(state.filters.copyWith(onlyOpen: selected));
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.swap_vert, size: 16, color: AppColors.primary),
                  label: Text(_sort == RestaurantSort.relevance ? 'Sort' : _sort.label),
                  onPressed: () async {
                    final selected = await showRestaurantSortSheet(context, _sort);
                    if (selected != null) setState(() => _sort = selected);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(RestaurantListState state) {
    if (state.isLoading && state.restaurants.isEmpty) {
      return const LoadingIndicator();
    }
    if (state.failure != null && state.restaurants.isEmpty) {
      return ErrorView(failure: state.failure!, onRetry: () => ref.read(restaurantListProvider.notifier).refresh());
    }
    if (state.restaurants.isEmpty) {
      return const EmptyView(
        title: 'No restaurants found',
        message: 'Try adjusting your search or filters.',
        icon: Icons.storefront_outlined,
      );
    }

    final sorted = _sort.apply(state.restaurants);

    return RefreshIndicator(
      onRefresh: () => ref.read(restaurantListProvider.notifier).refresh(),
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          childAspectRatio: 2.2,
          mainAxisSpacing: 14,
        ),
        itemCount: sorted.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= sorted.length) {
            return const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LoadingIndicator(size: 20));
          }
          final restaurant = sorted[index];
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
