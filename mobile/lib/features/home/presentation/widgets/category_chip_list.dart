import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../restaurants/data/models/restaurant_model.dart';

class CategoryChipList extends StatelessWidget {
  final List<RestaurantCategoryModel> categories;
  final String? selectedSlug;
  final void Function(RestaurantCategoryModel category) onTap;

  const CategoryChipList({super.key, required this.categories, required this.onTap, this.selectedSlug});

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category.slug.isNotEmpty && category.slug == selectedSlug;
          return InkWell(
            onTap: () => onTap(category),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 68,
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: selected ? Border.all(color: AppColors.primary, width: 2) : null,
                        ),
                        padding: EdgeInsets.all(selected ? 3 : 0),
                        child: Container(
                          decoration: const BoxDecoration(color: AppColors.chipBackground, shape: BoxShape.circle),
                          clipBehavior: Clip.antiAlias,
                          child: category.iconUrl != null
                              ? AppNetworkImage(url: category.iconUrl!, width: 60, height: 60)
                              : const Icon(Icons.restaurant_menu, color: AppColors.primary),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 1.5),
                            ),
                            child: const Icon(Icons.check, size: 10, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    style: selected
                        ? AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)
                        : AppTextStyles.caption,
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
