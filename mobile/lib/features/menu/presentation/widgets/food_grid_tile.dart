import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../data/models/food_model.dart';
import 'veg_indicator.dart';

/// Image-forward grid card for a restaurant's menu — a photo of the dish up
/// top, name/rating below, and the price + "ADD" button side by side at the
/// bottom, fully contained within the card.
class FoodGridTile extends StatelessWidget {
  final FoodModel food;
  final VoidCallback onTap;

  const FoodGridTile({super.key, required this.food, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = !food.isOrderable;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Opacity(
                  opacity: disabled ? 0.5 : 1,
                  child: AspectRatio(
                    aspectRatio: 1.3,
                    child: AppNetworkImage(url: food.displayImageUrl, width: double.infinity, height: double.infinity),
                  ),
                ),
                Positioned(top: 8, left: 8, child: VegIndicator(isVeg: food.isVeg)),
                if (food.isBestseller)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.ratingGold, borderRadius: BorderRadius.circular(4)),
                      child: const Text(
                        'Bestseller',
                        style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                if (disabled)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black26,
                      child: Center(
                        child: Text('Unavailable', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    food.name,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (food.totalReviews > 0) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 13, color: AppColors.secondary),
                        const SizedBox(width: 2),
                        Text('${food.averageRating.toStringAsFixed(1)} (${food.totalReviews})', style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (food.pricing.hasDiscount)
                              Text(
                                Formatters.currency(food.pricing.unitPrice),
                                style: AppTextStyles.caption.copyWith(decoration: TextDecoration.lineThrough),
                              ),
                            Text(
                              Formatters.currency(food.pricing.finalPrice),
                              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (!disabled)
                        SizedBox(
                          height: 30,
                          child: OutlinedButton(
                            onPressed: onTap,
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(54, 30),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: const Text('ADD', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ),
                    ],
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
