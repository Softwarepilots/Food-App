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
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Opacity(
                  opacity: closed ? 0.5 : 1,
                  child: AppNetworkImage(url: restaurant.displayImageUrl, height: 140, width: double.infinity),
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
                if (restaurant.distanceKm != null)
                  Positioned(
                    right: onFavoriteToggle != null ? 52 : 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        Formatters.distanceKm(restaurant.distanceKm!),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
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
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: Icon(
                          restaurant.isFavorite ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: restaurant.isFavorite ? AppColors.secondary : Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      RatingBadge(rating: restaurant.averageRating, compact: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    restaurant.cuisineTags.isNotEmpty ? restaurant.cuisineTags.join(', ') : restaurant.city,
                    style: AppTextStyles.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${restaurant.avgPrepTimeMinutes}-${restaurant.avgPrepTimeMinutes + 10} min', style: AppTextStyles.caption),
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
