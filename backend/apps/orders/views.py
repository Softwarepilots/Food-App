from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.views import APIView

from apps.accounts.permissions import IsRestaurantOwner
from apps.common.pagination import paginated_response
from apps.common.response import APIResponse
from apps.restaurants.permissions import IsRestaurantOwnerOfObject

from . import services
from .models import Order
from .serializers import OrderCancelSerializer, OrderCreateSerializer, OrderSerializer, OrderStatusUpdateSerializer


@extend_schema(tags=["Orders"])
class OrderListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(summary="List the current user's orders, most recent first")
    def get(self, request):
        queryset = Order.objects.filter(user=request.user)
        return paginated_response(request, self, queryset, OrderSerializer)

    @extend_schema(summary="Place an order from the current cart")
    def post(self, request):
        serializer = OrderCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        order = services.place_order(
            request.user,
            restaurant_id=data["restaurant_id"],
            address_id=data["delivery_address_id"],
            items_payload=data["items"],
            payment_method=data["payment_method"],
            notes=data.get("notes", ""),
        )
        return APIResponse(data=OrderSerializer(order).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Orders"], summary="Get order details")
class OrderDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        order = get_object_or_404(Order, pk=pk, user=request.user)
        return APIResponse(data=OrderSerializer(order).data)


@extend_schema(tags=["Orders"], summary="Cancel an order (only while placed/accepted)")
class OrderCancelView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        order = get_object_or_404(Order, pk=pk, user=request.user)
        serializer = OrderCancelSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        order = services.cancel_order(order, request.user, serializer.validated_data.get("reason", ""))
        return APIResponse(data=OrderSerializer(order).data)


@extend_schema(tags=["Orders"], summary="List incoming orders for the current restaurant owner's restaurant(s)")
class RestaurantOrdersView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwner]

    def get(self, request):
        queryset = Order.objects.filter(restaurant__owner=request.user)
        status_filter = request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return paginated_response(request, self, queryset, OrderSerializer)


@extend_schema(tags=["Orders"], summary="Advance an order's status (restaurant owner only)")
class OrderStatusUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwnerOfObject]

    def patch(self, request, pk):
        order = get_object_or_404(Order, pk=pk)
        self.check_object_permissions(request, order)
        serializer = OrderStatusUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        order = services.update_order_status(order, serializer.validated_data["status"])
        return APIResponse(data=OrderSerializer(order).data)
