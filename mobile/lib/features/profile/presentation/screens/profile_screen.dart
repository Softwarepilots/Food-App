import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_network_image.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/profile_menu_tile.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to log out of your account?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (context.mounted) context.go(RoutePaths.phoneEntry);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              ClipOval(
                child: user?.profileImageUrl != null
                    ? AppNetworkImage(url: user!.profileImageUrl!, width: 64, height: 64)
                    : Container(
                        width: 64,
                        height: 64,
                        color: AppColors.chipBackground,
                        child: const Icon(Icons.person, size: 32, color: AppColors.textSecondary),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.fullName ?? '', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 4),
                    Text(user?.phoneNumber ?? '', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    if (user?.email != null)
                      Text(user!.email!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.divider),
          ProfileMenuTile(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            onTap: () => context.push('/profile/edit'),
          ),
          const Divider(color: AppColors.divider, height: 1),
          ProfileMenuTile(
            icon: Icons.location_on_outlined,
            title: 'My addresses',
            onTap: () => context.push('/profile/addresses'),
          ),
          const Divider(color: AppColors.divider, height: 1),
          ProfileMenuTile(
            icon: Icons.receipt_long_outlined,
            title: 'My orders',
            onTap: () => context.push('/orders'),
          ),
          const Divider(color: AppColors.divider, height: 1),
          ProfileMenuTile(
            icon: Icons.favorite_border,
            title: 'My favorites',
            onTap: () => context.push(RoutePaths.favorites),
          ),
          const Divider(color: AppColors.divider, height: 1),
          ProfileMenuTile(
            icon: Icons.logout,
            title: 'Log out',
            iconColor: AppColors.error,
            textColor: AppColors.error,
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }
}
