import '../../domain/repositories/address_repository.dart';
import '../datasources/address_remote_datasource.dart';
import '../models/address_model.dart';

class AddressRepositoryImpl implements AddressRepository {
  final AddressRemoteDataSource _remoteDataSource;

  AddressRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<AddressModel>> getAddresses() => _remoteDataSource.getAddresses();

  @override
  Future<AddressModel> createAddress(AddressModel address) => _remoteDataSource.createAddress(address);

  @override
  Future<AddressModel> updateAddress(String id, AddressModel address) =>
      _remoteDataSource.updateAddress(id, address);

  @override
  Future<void> deleteAddress(String id) => _remoteDataSource.deleteAddress(id);

  @override
  Future<AddressModel> setDefault(String id) => _remoteDataSource.setDefault(id);
}
