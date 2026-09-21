import '../../../../core/network/api_response.dart';
import '../../data/models/order_model.dart';

abstract class OrderRepository {
  Future<OrderModel> createOrder({
    required String restaurantId,
    required String addressId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? notes,
  });

  Future<PaginatedResult<OrderModel>> getOrders({int page = 1});

  Future<OrderModel> getOrderDetail(String id);

  Future<OrderModel> cancelOrder(String id, {String? reason});

  Future<void> submitReview(String orderId, {required int rating, String? comment, int? deliveryRating});
}
