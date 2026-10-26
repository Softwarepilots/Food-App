import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/food_model.dart';
import '../providers/menu_provider.dart';

/// Read-only — shows what other customers rated this dish while browsing.
/// Writing a review happens only after *your own* order is delivered (see
/// OrderReviewCard), matching Swiggy: you can't rate something you haven't
/// received yet.
class FoodReviewsSection extends ConsumerWidget {
  final FoodModel food;

  const FoodReviewsSection({super.key, required this.food});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(foodReviewsProvider(food.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ratings & Reviews', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        reviewsAsync.when(
          loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: LoadingIndicator(size: 20)),
          error: (error, _) => Text(Failure.fromException(error).message, style: AppTextStyles.bodySmall),
          data: (reviews) {
            if (reviews.isEmpty) {
              return Text('No reviews yet — be the first to rate this dish.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary));
            }
            return Column(
              children: [
                for (final review in reviews) ...[
                  _ReviewTile(review: review),
                  const Divider(color: AppColors.divider, height: 1),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final FoodReviewModel review;

  const _ReviewTile({required this.review});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(review.userName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Icon(Icons.star_rounded, size: 14, color: AppColors.secondary),
              const SizedBox(width: 2),
              Text('${review.rating}', style: AppTextStyles.caption),
              const Spacer(),
              Text(Formatters.relative(review.createdAt), style: AppTextStyles.caption),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(review.comment, style: AppTextStyles.bodySmall),
          ],
        ],
      ),
    );
  }
}
