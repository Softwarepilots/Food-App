import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../restaurant/presentation/providers/restaurant_provider.dart';
import '../providers/menu_provider.dart';
import 'add_food_screen.dart';

class MenuListScreen extends ConsumerWidget {
  const MenuListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurant = ref.watch(myRestaurantProvider).value;
    if (restaurant == null) {
      return const Scaffold(body: Center(child: Text('Set up your restaurant first.')));
    }

    final menuAsync = ref.watch(menuProvider(restaurant.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddFoodScreen(restaurantId: restaurant.id)),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: menuAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          failure: Failure.fromException(error),
          onRetry: () => ref.read(menuProvider(restaurant.id).notifier).refresh(),
        ),
        data: (foods) {
          if (foods.isEmpty) {
            return const EmptyView(
              title: 'No dishes yet',
              message: 'Tap + to add your first menu item.',
              icon: Icons.restaurant_menu_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(menuProvider(restaurant.id).notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: foods.length,
              separatorBuilder: (_, _) => const Divider(color: AppColors.divider, height: 1),
              itemBuilder: (context, index) {
                final food = foods[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      AppNetworkImage(url: food.imageUrl, width: 56, height: 56, borderRadius: BorderRadius.circular(10)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(food.name, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text(Formatters.currency(food.basePrice), style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                      Switch(
                        activeThumbColor: AppColors.primary,
                        value: food.isAvailable,
                        onChanged: (value) async {
                          try {
                            await ref.read(menuProvider(restaurant.id).notifier).toggleAvailability(food.id, value);
                          } catch (e) {
                            if (!context.mounted) return;
                            final failure = Failure.fromException(e);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
                          }
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
