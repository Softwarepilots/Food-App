import '../../../../core/network/api_response.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_datasource.dart';
import '../models/order_model.dart';

class OrderRepositoryImpl implements OrderRepository {
  final OrderRemoteDataSource _remoteDataSource;

  OrderRepositoryImpl(this._remoteDataSource);

  @override
  Future<OrderModel> createOrder({
    required String restaurantId,
    required String addressId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? notes,
  }) {
    return _remoteDataSource.createOrder(
      restaurantId: restaurantId,
      addressId: addressId,
      items: items,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }

  @override
  Future<PaginatedResult<OrderModel>> getOrders({int page = 1}) => _remoteDataSource.getOrders(page: page);

  @override
  Future<OrderModel> getOrderDetail(String id) => _remoteDataSource.getOrderDetail(id);

  @override
  Future<OrderModel> cancelOrder(String id, {String? reason}) => _remoteDataSource.cancelOrder(id, reason: reason);
}
