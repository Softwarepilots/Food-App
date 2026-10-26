import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../data/models/restaurant_model.dart';
import 'rating_badge.dart';

class RestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteToggle;

  const RestaurantCard({super.key, required this.restaurant, required this.onTap, this.onFavoriteToggle});

  @override
  Widget build(BuildContext context) {
    final closed = !restaurant.isOpen;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Opacity(
                  opacity: closed ? 0.5 : 1,
                  child: AppNetworkImage(url: restaurant.displayImageUrl, height: 160, width: double.infinity),
                ),
                if (closed)
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(6)),
                      child: const Text('Closed', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                  ),
                if (onFavoriteToggle != null)
                  Positioned(
                    right: 12,
                    top: 12,
                    child: InkWell(
                      onTap: onFavoriteToggle,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                        child: Icon(
                          restaurant.isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: restaurant.isFavorite ? AppColors.secondary : Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 13, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${restaurant.avgPrepTimeMinutes}-${restaurant.avgPrepTimeMinutes + 10} mins',
                          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                if (restaurant.distanceKm != null)
                  Positioned(
                    left: 12,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        Formatters.distanceKm(restaurant.distanceKm!),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurant.name,
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      RatingBadge(rating: restaurant.averageRating, compact: true),
                      if (restaurant.totalReviews > 0) ...[
                        const SizedBox(width: 6),
                        Text('(${restaurant.totalReviews})', style: AppTextStyles.caption),
                      ],
                      const SizedBox(width: 6),
                      const Text('•', style: TextStyle(color: AppColors.textDisabled)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          restaurant.city,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (restaurant.cuisineTags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      restaurant.cuisineTags.join(', '),
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
