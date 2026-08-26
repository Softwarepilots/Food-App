import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/food_model.dart';

class VariantSelector extends StatelessWidget {
  final List<FoodVariantModel> variants;
  final FoodVariantModel? selected;
  final ValueChanged<FoodVariantModel> onSelected;

  const VariantSelector({super.key, required this.variants, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose an option', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        ...variants.map((variant) {
          final disabled = !variant.isOrderable;
          return Opacity(
            opacity: disabled ? 0.5 : 1,
            child: RadioListTile<String>(
              value: variant.id,
              groupValue: selected?.id,
              onChanged: disabled ? null : (_) => onSelected(variant),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
              title: Text(variant.name, style: AppTextStyles.bodyMedium),
              subtitle: disabled ? const Text('Out of stock') : null,
              secondary: Text(Formatters.currency(variant.price), style: AppTextStyles.bodyMedium),
            ),
          );
        }),
      ],
    );
  }
}
