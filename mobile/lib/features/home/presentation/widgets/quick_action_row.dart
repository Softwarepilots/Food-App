import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class QuickActionRow extends StatelessWidget {
  final VoidCallback onOffers;
  final VoidCallback onFastDelivery;
  final VoidCallback onNearMe;
  final VoidCallback onPopular;

  const QuickActionRow({
    super.key,
    required this.onOffers,
    required this.onFastDelivery,
    required this.onNearMe,
    required this.onPopular,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _QuickAction(icon: Icons.local_offer_outlined, label: 'Offers', onTap: onOffers),
          _QuickAction(icon: Icons.two_wheeler_outlined, label: 'Fast Delivery', onTap: onFastDelivery),
          _QuickAction(icon: Icons.near_me_outlined, label: 'Near Me', onTap: onNearMe),
          _QuickAction(icon: Icons.workspace_premium_outlined, label: 'Popular', onTap: onPopular),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Icon(icon, color: AppColors.secondary, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
