import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../restaurants/data/models/restaurant_model.dart';

class CategoryChipList extends StatelessWidget {
  final List<RestaurantCategoryModel> categories;
  final void Function(RestaurantCategoryModel category) onTap;

  const CategoryChipList({super.key, required this.categories, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];
          return InkWell(
            onTap: () => onTap(category),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: AppColors.chipBackground, shape: BoxShape.circle),
                    clipBehavior: Clip.antiAlias,
                    child: category.iconUrl != null
                        ? AppNetworkImage(url: category.iconUrl!, width: 60, height: 60)
                        : const Icon(Icons.restaurant_menu, color: AppColors.primary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
