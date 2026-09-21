from django.db.models import Q
from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.views import APIView

from apps.accounts.permissions import IsAdminRole, IsRestaurantOwner
from apps.common.pagination import paginated_response
from apps.common.response import APIResponse
from apps.restaurants.permissions import IsRestaurantTeamMember

from . import services
from .models import Order
from .serializers import (
    OrderCancelSerializer,
    OrderCreateSerializer,
    OrderSerializer,
    OrderStatusUpdateSerializer,
    ReviewCreateSerializer,
    ReviewSerializer,
)


@extend_schema(tags=["Orders"])
class OrderListCreateView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @extend_schema(summary="List the current user's orders, most recent first")
    def get(self, request):
        services.auto_reject_expired_orders()
        queryset = Order.objects.filter(user=request.user).select_related("user")
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
        services.auto_reject_expired_orders(Order.objects.filter(pk=order.pk))
        order.refresh_from_db()
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


@extend_schema(tags=["Orders"], summary="Submit (or update) a review for a delivered order — rates the restaurant and, if a rider was assigned, the delivery partner too")
class OrderReviewView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        order = get_object_or_404(Order, pk=pk, user=request.user)
        serializer = ReviewCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        review, created = services.submit_review(order, request.user, **serializer.validated_data)
        return APIResponse(
            data=ReviewSerializer(review).data, status=status.HTTP_201_CREATED if created else status.HTTP_200_OK
        )


@extend_schema(tags=["Orders"], summary="List incoming orders for restaurant(s) the current user owns or staffs")
class RestaurantOrdersView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantOwner]

    def get(self, request):
        services.auto_reject_expired_orders()
        queryset = Order.objects.filter(
            Q(restaurant__owner=request.user)
            | Q(restaurant__staff_members__user=request.user, restaurant__staff_members__is_active=True)
        ).distinct().select_related("user")
        status_filter = request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return paginated_response(request, self, queryset, OrderSerializer)


@extend_schema(tags=["Admin"], summary="List every order platform-wide, optionally filtered by status (admin only)")
class AdminOrderListView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def get(self, request):
        services.auto_reject_expired_orders()
        queryset = Order.objects.all().select_related("user")
        status_filter = request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return paginated_response(request, self, queryset, OrderSerializer)


@extend_schema(tags=["Orders"], summary="Advance an order's status (restaurant owner/manager/staff)")
class OrderStatusUpdateView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsRestaurantTeamMember]

    def patch(self, request, pk):
        order = get_object_or_404(Order, pk=pk)
        self.check_object_permissions(request, order)
        services.auto_reject_expired_orders(Order.objects.filter(pk=order.pk))
        order.refresh_from_db()
        serializer = OrderStatusUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        order = services.update_order_status(
            order,
            serializer.validated_data["status"],
            prep_time_minutes=serializer.validated_data.get("prep_time_minutes"),
        )
        return APIResponse(data=OrderSerializer(order).data)
