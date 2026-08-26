import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/address_remote_datasource.dart';
import '../../data/models/address_model.dart';
import '../../data/repositories/address_repository_impl.dart';
import '../../domain/repositories/address_repository.dart';

final addressRemoteDataSourceProvider = Provider<AddressRemoteDataSource>((ref) {
  return AddressRemoteDataSource(ref.watch(dioProvider));
});

final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepositoryImpl(ref.watch(addressRemoteDataSourceProvider));
});

class AddressListState extends Equatable {
  final List<AddressModel> addresses;
  final bool isLoading;
  final Failure? failure;
  final String? selectedAddressId;

  const AddressListState({
    this.addresses = const [],
    this.isLoading = false,
    this.failure,
    this.selectedAddressId,
  });

  AddressModel? get selectedAddress {
    if (addresses.isEmpty) return null;
    if (selectedAddressId != null) {
      for (final address in addresses) {
        if (address.id == selectedAddressId) return address;
      }
    }
    for (final address in addresses) {
      if (address.isDefault) return address;
    }
    return addresses.first;
  }

  AddressListState copyWith({
    List<AddressModel>? addresses,
    bool? isLoading,
    Failure? failure,
    bool clearFailure = false,
    String? selectedAddressId,
  }) {
    return AddressListState(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      failure: clearFailure ? null : (failure ?? this.failure),
      selectedAddressId: selectedAddressId ?? this.selectedAddressId,
    );
  }

  @override
  List<Object?> get props => [addresses, isLoading, failure, selectedAddressId];
}

class AddressListNotifier extends Notifier<AddressListState> {
  @override
  AddressListState build() {
    Future.microtask(loadAddresses);
    return const AddressListState();
  }

  Future<void> loadAddresses() async {
    state = state.copyWith(isLoading: true, clearFailure: true);
    try {
      final addresses = await ref.read(addressRepositoryProvider).getAddresses();
      state = state.copyWith(addresses: addresses, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, failure: Failure.fromException(e));
    }
  }

  void selectAddress(String id) {
    state = state.copyWith(selectedAddressId: id);
  }

  Future<AddressModel> createAddress(AddressModel address) async {
    final created = await ref.read(addressRepositoryProvider).createAddress(address);
    state = state.copyWith(addresses: [...state.addresses, created], selectedAddressId: created.id);
    return created;
  }

  Future<void> deleteAddress(String id) async {
    await ref.read(addressRepositoryProvider).deleteAddress(id);
    state = state.copyWith(addresses: state.addresses.where((a) => a.id != id).toList());
  }

  Future<void> setDefault(String id) async {
    final updated = await ref.read(addressRepositoryProvider).setDefault(id);
    state = state.copyWith(
      addresses: [
        for (final a in state.addresses)
          if (a.id == updated.id) updated else AddressModel(
            id: a.id,
            label: a.label,
            addressLine1: a.addressLine1,
            addressLine2: a.addressLine2,
            city: a.city,
            state: a.state,
            pincode: a.pincode,
            latitude: a.latitude,
            longitude: a.longitude,
            isDefault: false,
          ),
      ],
    );
  }
}

final addressListProvider = NotifierProvider<AddressListNotifier, AddressListState>(AddressListNotifier.new);
