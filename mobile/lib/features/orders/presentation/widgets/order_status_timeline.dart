import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/order_model.dart';

/// Horizontal step tracker (Confirmed → Preparing → On the way → Delivered),
/// mirroring the brand's track-order screen. Cancelled orders show a single
/// banner instead.
class OrderStatusTimeline extends StatelessWidget {
  final OrderModel order;

  const OrderStatusTimeline({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    if (order.status.isCancelled) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: AppColors.error),
            const SizedBox(width: 10),
            const Expanded(child: Text('This order was cancelled.', style: TextStyle(color: AppColors.error))),
          ],
        ),
      );
    }

    final currentIndex = order.status.stepIndex;
    // Collapse the 6 backend statuses onto the 4 brand-facing steps.
    const steps = ['Confirmed', 'Preparing', 'On the way', 'Delivered'];
    final stepThresholds = [0, 2, 4, 5]; // maps into OrderStatusX.timeline indices

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                _StepDot(isDone: currentIndex >= stepThresholds[i]),
                const SizedBox(height: 6),
                Text(
                  steps[i],
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: currentIndex >= stepThresholds[i] ? AppColors.textPrimary : AppColors.textDisabled,
                    fontWeight: currentIndex >= stepThresholds[i] ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          if (i != steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Container(
                width: 20,
                height: 2,
                color: currentIndex >= stepThresholds[i + 1] ? AppColors.primary : AppColors.divider,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool isDone;

  const _StepDot({required this.isDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDone ? AppColors.primary : AppColors.chipBackground,
        border: isDone ? null : Border.all(color: AppColors.divider),
      ),
      child: Icon(
        isDone ? Icons.check : Icons.circle,
        size: isDone ? 16 : 8,
        color: isDone ? AppColors.secondary : AppColors.textDisabled,
      ),
    );
  }
}
