import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

/// Shows the cart's item subtotal only — delivery fee, taxes, and any
/// coupon discount are computed server-side at checkout since they depend
/// on the delivery address and live restaurant charges.
class CartSummary extends StatelessWidget {
  final double subtotal;
  final int itemCount;

  const CartSummary({super.key, required this.subtotal, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bill summary', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Item total ($itemCount item${itemCount > 1 ? 's' : ''})', style: AppTextStyles.bodyMedium),
              Text(Formatters.currency(subtotal), style: AppTextStyles.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Delivery fee, taxes, and discounts are calculated at checkout.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
          const Divider(height: 24, color: AppColors.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('To pay', style: AppTextStyles.titleMedium),
              Text(Formatters.currency(subtotal), style: AppTextStyles.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}
