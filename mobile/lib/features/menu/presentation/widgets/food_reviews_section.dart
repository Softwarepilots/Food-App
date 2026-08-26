import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../data/models/food_model.dart';
import '../providers/menu_provider.dart';
import 'star_rating_input.dart';

class FoodReviewsSection extends ConsumerStatefulWidget {
  final FoodModel food;

  const FoodReviewsSection({super.key, required this.food});

  @override
  ConsumerState<FoodReviewsSection> createState() => _FoodReviewsSectionState();
}

class _FoodReviewsSectionState extends ConsumerState<FoodReviewsSection> {
  int _draftRating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_draftRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tap a star to rate this dish')));
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ref.read(menuRepositoryProvider).submitFoodReview(
            foodId: widget.food.id,
            rating: _draftRating,
            comment: _commentController.text.trim(),
          );
      _commentController.clear();
      setState(() => _draftRating = 0);
      ref.invalidate(foodReviewsProvider(widget.food.id));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thanks for rating this dish!')));
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(foodReviewsProvider(widget.food.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ratings & Reviews', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.chipBackground, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rate this dish', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 8),
              StarRatingInput(rating: _draftRating, onChanged: (v) => setState(() => _draftRating = v)),
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Share your thoughts (optional)'),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(_isSubmitting ? 'Submitting...' : 'Submit'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
