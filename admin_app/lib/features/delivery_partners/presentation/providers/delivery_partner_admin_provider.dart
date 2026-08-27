import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/delivery_partner_admin_remote_datasource.dart';
import '../../data/models/delivery_partner_admin_model.dart';

final deliveryPartnerAdminRemoteDataSourceProvider = Provider<DeliveryPartnerAdminRemoteDataSource>((ref) {
  return DeliveryPartnerAdminRemoteDataSource(ref.watch(dioProvider));
});

/// `null` means "All".
enum DeliveryVerificationFilter { all, verified, unverified }

extension DeliveryVerificationFilterX on DeliveryVerificationFilter {
  bool? get apiValue {
    switch (this) {
      case DeliveryVerificationFilter.all:
        return null;
      case DeliveryVerificationFilter.verified:
        return true;
      case DeliveryVerificationFilter.unverified:
        return false;
    }
  }

  String get label {
    switch (this) {
      case DeliveryVerificationFilter.all:
        return 'All';
      case DeliveryVerificationFilter.verified:
        return 'Verified';
      case DeliveryVerificationFilter.unverified:
        return 'Unverified';
    }
  }
}

class DeliveryPartnerAdminListState extends Equatable {
  final List<DeliveryPartnerAdminModel> partners;
  final DeliveryVerificationFilter filter;
  final bool isLoading;
  final Failure? failure;

  const DeliveryPartnerAdminListState({
    this.partners = const [],
    this.filter = DeliveryVerificationFilter.all,
    this.isLoading = false,
    this.failure,
  });

  DeliveryPartnerAdminListState copyWith({
    List<DeliveryPartnerAdminModel>? partners,
    DeliveryVerificationFilter? filter,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return DeliveryPartnerAdminListState(
      partners: partners ?? this.partners,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [partners, filter, isLoading, failure];
}

class DeliveryPartnerAdminListNotifier extends Notifier<DeliveryPartnerAdminListState> {
  @override
  DeliveryPartnerAdminListState build() {
    Future.microtask(refresh);
    return const DeliveryPartnerAdminListState(isLoading: true);
  }

  Future<void> setFilter(DeliveryVerificationFilter filter) async {
    state = state.copyWith(filter: filter);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final result = await ref
          .read(deliveryPartnerAdminRemoteDataSourceProvider)
          .getPartners(isVerified: state.filter.apiValue);
      state = state.copyWith(partners: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  Future<void> setVerified(String partnerId, bool isVerified) async {
    final updated = await ref.read(deliveryPartnerAdminRemoteDataSourceProvider).setVerified(partnerId, isVerified);
    final filterValue = state.filter.apiValue;
    final stillMatches = filterValue == null || updated.isVerified == filterValue;
    state = state.copyWith(
      partners: stillMatches
          ? [for (final p in state.partners) if (p.id == partnerId) updated else p]
          : [for (final p in state.partners) if (p.id != partnerId) p],
    );
  }
}

final deliveryPartnerAdminListProvider =
    NotifierProvider<DeliveryPartnerAdminListNotifier, DeliveryPartnerAdminListState>(
  DeliveryPartnerAdminListNotifier.new,
);
