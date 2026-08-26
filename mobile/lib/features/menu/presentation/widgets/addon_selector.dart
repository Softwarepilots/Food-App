import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/models/food_model.dart';

class AddonSelector extends StatelessWidget {
  final List<FoodAddonModel> addons;
  final Map<String, int> quantities;
  final void Function(String addonId, int quantity) onChanged;

  const AddonSelector({super.key, required this.addons, required this.quantities, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (addons.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add-ons', style: AppTextStyles.titleMedium),
        const SizedBox(height: 8),
        ...addons.map((addon) {
          final qty = quantities[addon.id] ?? 0;
          final disabled = !addon.isAvailable;
          return Opacity(
            opacity: disabled ? 0.5 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(addon.name, style: AppTextStyles.bodyMedium),
                        Text('+${Formatters.currency(addon.price)}', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  if (!disabled)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 22),
                          color: qty > 0 ? AppColors.primary : AppColors.textDisabled,
                          onPressed: qty > 0 ? () => onChanged(addon.id, qty - 1) : null,
                        ),
                        SizedBox(width: 20, child: Text('$qty', textAlign: TextAlign.center, style: AppTextStyles.bodyMedium)),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, size: 22),
                          color: qty < addon.maxQuantity ? AppColors.primary : AppColors.textDisabled,
                          onPressed: qty < addon.maxQuantity ? () => onChanged(addon.id, qty + 1) : null,
                        ),
                      ],
                    )
                  else
                    Text('Unavailable', style: AppTextStyles.caption),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
