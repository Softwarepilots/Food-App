import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The small green/red square-with-dot marker used everywhere a dish's
/// veg/non-veg status is shown (list rows, grid cards).
class VegIndicator extends StatelessWidget {
  final bool isVeg;
  final double size;

  const VegIndicator({super.key, required this.isVeg, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final color = isVeg ? AppColors.vegGreen : AppColors.nonVegRed;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.2), borderRadius: BorderRadius.circular(3)),
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    );
  }
}
