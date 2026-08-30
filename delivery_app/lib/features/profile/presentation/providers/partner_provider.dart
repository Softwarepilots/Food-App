import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/partner_remote_datasource.dart';
import '../../data/models/partner_profile_model.dart';

final partnerRemoteDataSourceProvider = Provider<PartnerRemoteDataSource>((ref) {
  return PartnerRemoteDataSource(ref.watch(dioProvider));
});

/// Gates access to the main app on whether the logged-in delivery partner has
/// created their profile yet (analogous to the restaurant-owner app's
/// "has a restaurant been set up" gate).
class MyPartnerProfileNotifier extends AsyncNotifier<PartnerProfileModel?> {
  @override
  Future<PartnerProfileModel?> build() async {
    // Watching authProvider (not just reading it) means this refetches
    // automatically whenever login/logout changes auth state.
    final authState = ref.watch(authProvider);
    if (!authState.isAuthenticated) return null;

    return ref.watch(partnerRemoteDataSourceProvider).getProfile();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(partnerRemoteDataSourceProvider).getProfile());
  }

  Future<void> createProfile({
    required String vehicleType,
    required String vehicleNumber,
    required String licenseNumber,
  }) async {
    final profile = await ref.read(partnerRemoteDataSourceProvider).createProfile(
          vehicleType: vehicleType,
          vehicleNumber: vehicleNumber,
          licenseNumber: licenseNumber,
        );
    state = AsyncValue.data(profile);
  }

  Future<void> goOnline() async {
    final profile = await ref.read(partnerRemoteDataSourceProvider).updateStatus('online');
    state = AsyncValue.data(profile);
  }

  Future<void> goOffline() async {
    final profile = await ref.read(partnerRemoteDataSourceProvider).updateStatus('offline');
    state = AsyncValue.data(profile);
  }
}

final myPartnerProfileProvider = AsyncNotifierProvider<MyPartnerProfileNotifier, PartnerProfileModel?>(
  MyPartnerProfileNotifier.new,
);
