import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class RatingBadge extends StatelessWidget {
  final double rating;
  final bool compact;

  const RatingBadge({super.key, required this.rating, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final hasRating = rating > 0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: hasRating ? AppColors.primary : AppColors.chipBackground,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: compact ? 12 : 14, color: hasRating ? AppColors.secondary : AppColors.textDisabled),
          const SizedBox(width: 3),
          Text(
            hasRating ? rating.toStringAsFixed(1) : 'New',
            style: AppTextStyles.caption.copyWith(
              color: hasRating ? Colors.white : AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
