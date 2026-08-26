import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../cart/data/models/cart_item_model.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../data/models/food_model.dart';
import '../providers/food_selection_provider.dart';
import '../widgets/addon_selector.dart';
import '../widgets/food_reviews_section.dart';
import '../widgets/variant_selector.dart';

class FoodDetailsScreen extends ConsumerWidget {
  final FoodModel food;
  final String restaurantId;
  final String restaurantName;

  const FoodDetailsScreen({
    super.key,
    required this.food,
    required this.restaurantId,
    required this.restaurantName,
  });

  Future<void> _addToCart(BuildContext context, WidgetRef ref, FoodSelectionState selection) async {
    final cartItem = CartItemModel(
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      food: selection.food,
      variant: selection.selectedVariant,
      addonQuantities: selection.addonQuantities,
      quantity: selection.quantity,
      notes: selection.notes,
    );

    try {
      ref.read(cartProvider.notifier).addItem(cartItem);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
        Navigator.of(context).pop();
      }
    } on DifferentRestaurantException catch (e) {
      if (!context.mounted) return;
      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Start a new cart?'),
          content: Text(
            'Your cart has items from ${e.existingRestaurantName}. Adding this item will clear your current cart.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start new cart')),
          ],
        ),
      );
      if (shouldReplace == true) {
        ref.read(cartProvider.notifier).clear();
        ref.read(cartProvider.notifier).addItem(cartItem);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${food.name} added to cart')));
          Navigator.of(context).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(foodSelectionProvider(food));
    final notifier = ref.read(foodSelectionProvider(food).notifier);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: AppNetworkImage(url: food.displayImageUrl, height: 220, width: double.infinity),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(food.name, style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(Formatters.currency(food.pricing.finalPrice), style: AppTextStyles.titleMedium),
                      if (food.totalReviews > 0) ...[
                        const SizedBox(width: 12),
                        Icon(Icons.star_rounded, size: 16, color: AppColors.secondary),
                        const SizedBox(width: 2),
                        Text(
                          '${food.averageRating.toStringAsFixed(1)} (${food.totalReviews})',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                  if (food.description != null && food.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(food.description!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                  if (food.calories != null) ...[
                    const SizedBox(height: 8),
                    Text('${food.calories} kcal', style: AppTextStyles.caption),
                  ],
                  const SizedBox(height: 20),
                  VariantSelector(
                    variants: food.variants,
                    selected: selection.selectedVariant,
                    onSelected: notifier.selectVariant,
                  ),
                  if (food.variants.isNotEmpty) const SizedBox(height: 20),
                  AddonSelector(
                    addons: food.addons,
                    quantities: selection.addonQuantities,
                    onChanged: notifier.setAddonQuantity,
                  ),
                  if (food.addons.isNotEmpty) const SizedBox(height: 20),
                  Text('Special instructions', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 2,
                    decoration: const InputDecoration(hintText: 'e.g. no onions, less spicy'),
                    onChanged: notifier.setNotes,
                  ),
                  const SizedBox(height: 24),
                  FoodReviewsSection(food: food),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.primary), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: AppColors.primary),
                      onPressed: selection.canDecreaseQuantity ? notifier.decrementQuantity : null,
                    ),
                    Text('${selection.quantity}', style: AppTextStyles.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primary),
                      onPressed: selection.canIncreaseQuantity ? notifier.incrementQuantity : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Add — ${Formatters.currency(selection.totalPrice)}',
                  onPressed: food.isOrderable ? () => _addToCart(context, ref, selection) : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
