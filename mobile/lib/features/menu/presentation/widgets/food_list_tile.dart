import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../data/models/food_model.dart';
import 'veg_indicator.dart';

class FoodListTile extends StatelessWidget {
  final FoodModel food;
  final VoidCallback onTap;

  const FoodListTile({super.key, required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = !food.isOrderable;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      VegIndicator(isVeg: food.isVeg),
                      const SizedBox(width: 6),
                      if (food.isBestseller)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.ratingGold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                          child: const Text('Bestseller', style: TextStyle(fontSize: 10, color: AppColors.ratingGold, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(food.name, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (food.totalReviews > 0) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 13, color: AppColors.secondary),
                        const SizedBox(width: 2),
                        Text(
                          '${food.averageRating.toStringAsFixed(1)} (${food.totalReviews})',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (food.pricing.hasDiscount) ...[
                        Text(
                          Formatters.currency(food.pricing.unitPrice),
                          style: AppTextStyles.bodySmall.copyWith(decoration: TextDecoration.lineThrough),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(Formatters.currency(food.pricing.finalPrice), style: AppTextStyles.bodyMedium),
                    ],
                  ),
                  if (food.description != null && food.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      food.description!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (disabled) ...[
                    const SizedBox(height: 4),
                    const Text('Currently unavailable', style: TextStyle(fontSize: 12, color: AppColors.error)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Opacity(
              opacity: disabled ? 0.5 : 1,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AppNetworkImage(
                    url: food.displayImageUrl,
                    width: 96,
                    height: 96,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  if (!disabled)
                    Positioned(
                      bottom: -10,
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          minimumSize: const Size(64, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
