import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_indicator.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/partner_profile_model.dart';
import '../providers/partner_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isTogglingStatus = false;

  Future<void> _toggleStatus(bool goOnline) async {
    setState(() => _isTogglingStatus = true);
    try {
      if (goOnline) {
        await ref.read(myPartnerProfileProvider.notifier).goOnline();
      } else {
        await ref.read(myPartnerProfileProvider.notifier).goOffline();
      }
    } catch (e) {
      if (!mounted) return;
      final failure = Failure.fromException(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isTogglingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myPartnerProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const LoadingIndicator(),
        error: (error, _) => ErrorView(
          failure: Failure.fromException(error),
          onRetry: () => ref.read(myPartnerProfileProvider.notifier).refresh(),
        ),
        data: (profile) {
          if (profile == null) {
            return const ErrorView(failure: Failure('Profile not found.'));
          }
          return _ProfileBody(
            profile: profile,
            isTogglingStatus: _isTogglingStatus,
            onToggleStatus: _toggleStatus,
          );
        },
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final PartnerProfileModel profile;
  final bool isTogglingStatus;
  final ValueChanged<bool> onToggleStatus;

  const _ProfileBody({required this.profile, required this.isTogglingStatus, required this.onToggleStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () => ref.read(myPartnerProfileProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.chipBackground,
                child: Text(
                  profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                  style: AppTextStyles.headlineSmall,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName, style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text(profile.phoneNumber, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _VerificationBadge(isVerified: profile.isVerified),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Go online', style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      profile.isOnline ? 'You are visible for new deliveries' : 'You are offline',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
                Switch(
                  value: profile.isOnline,
                  onChanged: isTogglingStatus ? null : onToggleStatus,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Rating', value: profile.ratingAvg.toStringAsFixed(2))),
              const SizedBox(width: 12),
              Expanded(child: _StatTile(label: 'Deliveries', value: '${profile.totalDeliveries}')),
            ],
          ),
          const SizedBox(height: 16),
          _InfoTile(icon: Icons.two_wheeler_outlined, label: 'Vehicle', value: profile.vehicleType.label),
          _InfoTile(icon: Icons.confirmation_number_outlined, label: 'Vehicle number', value: profile.vehicleNumber),
          _InfoTile(icon: Icons.badge_outlined, label: 'License number', value: profile.licenseNumber),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _VerificationBadge extends StatelessWidget {
  final bool isVerified;

  const _VerificationBadge({required this.isVerified});

  @override
  Widget build(BuildContext context) {
    final color = isVerified ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isVerified ? Icons.verified : Icons.hourglass_top_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            isVerified ? 'Verified' : 'Pending verification',
            style: AppTextStyles.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const Spacer(),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
