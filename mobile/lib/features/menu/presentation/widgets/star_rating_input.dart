import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class StarRatingInput extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  const StarRatingInput({super.key, required this.rating, required this.onChanged, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          InkWell(
            onTap: () => onChanged(i),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
                size: size,
                color: i <= rating ? AppColors.secondary : AppColors.textDisabled,
              ),
            ),
          ),
      ],
    );
  }
}
