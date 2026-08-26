import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class DeliveryPartnerCard extends StatelessWidget {
  final String name;
  final String? phone;

  const DeliveryPartnerCard({super.key, required this.name, this.phone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.chipBackground, shape: BoxShape.circle),
            child: const Icon(Icons.delivery_dining, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Delivery Partner', style: AppTextStyles.caption),
                Text(name, style: AppTextStyles.titleMedium),
              ],
            ),
          ),
          _CircleAction(
            icon: Icons.call,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(phone != null ? 'Calling $name...' : 'No phone number on file')),
            ),
          ),
          const SizedBox(width: 8),
          _CircleAction(
            icon: Icons.chat_bubble_outline,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Messaging is coming soon')),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
        child: Icon(icon, color: AppColors.secondary, size: 18),
      ),
    );
  }
}
