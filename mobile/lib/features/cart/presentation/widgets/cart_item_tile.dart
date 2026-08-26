import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../data/models/cart_item_model.dart';

class CartItemTile extends StatelessWidget {
  final CartItemModel item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppNetworkImage(url: item.food.displayImageUrl, width: 64, height: 64, borderRadius: BorderRadius.circular(10)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.food.name, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (item.variant != null) ...[
                  const SizedBox(height: 2),
                  Text(item.variant!.name, style: AppTextStyles.bodySmall),
                ],
                if (item.selectedAddons.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.selectedAddons.map((a) => a.name).join(', '),
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Note: ${item.notes}', style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic)),
                ],
                const SizedBox(height: 6),
                Text(Formatters.currency(item.lineTotal), style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.primary), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(item.quantity > 1 ? Icons.remove : Icons.delete_outline, size: 18, color: AppColors.primary),
                      onPressed: () => item.quantity > 1 ? onQuantityChanged(item.quantity - 1) : onRemove(),
                    ),
                    Text('${item.quantity}', style: AppTextStyles.bodyMedium),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18, color: AppColors.primary),
                      onPressed: () => onQuantityChanged(item.quantity + 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
