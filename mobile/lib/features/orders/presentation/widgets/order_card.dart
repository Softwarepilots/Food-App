import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../data/models/order_model.dart';

class OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const OrderCard({super.key, required this.order, required this.onTap});

  Color get _statusColor {
    if (order.status.isCancelled) return AppColors.error;
    if (order.status.isDelivered) return AppColors.success;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppNetworkImage(
              url: order.restaurantImageUrl ?? '',
              width: 56,
              height: 56,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(order.restaurantName, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                      Text(Formatters.currency(order.totalAmount), style: AppTextStyles.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${order.items.length} item${order.items.length > 1 ? 's' : ''} · #${order.orderNumber}',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(Formatters.dateTime(order.createdAt), style: AppTextStyles.caption),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                    child: Text(
                      order.status.label,
                      style: AppTextStyles.caption.copyWith(color: _statusColor, fontWeight: FontWeight.w600),
                    ),
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
