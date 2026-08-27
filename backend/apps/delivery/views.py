from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import permissions, status
from rest_framework.views import APIView

from apps.accounts.permissions import IsAdminRole, IsDeliveryPartner
from apps.common.pagination import paginated_response
from apps.common.response import APIResponse
from apps.orders.models import Order
from apps.orders.serializers import OrderSerializer

from . import services
from .models import DeliveryPartner
from .serializers import DeliveryPartnerProfileSerializer, DeliveryPartnerStatusUpdateSerializer


@extend_schema(tags=["Delivery"], summary="Get or create the current user's delivery partner profile")
class DeliveryPartnerProfileView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryPartner]

    def get(self, request):
        partner = get_object_or_404(DeliveryPartner, user=request.user)
        return APIResponse(data=DeliveryPartnerProfileSerializer(partner).data)

    def post(self, request):
        serializer = DeliveryPartnerProfileSerializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        partner = serializer.save()
        return APIResponse(data=DeliveryPartnerProfileSerializer(partner).data, status=status.HTTP_201_CREATED)


@extend_schema(tags=["Delivery"], summary="Go online/offline")
class DeliveryPartnerStatusView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryPartner]

    def patch(self, request):
        partner = get_object_or_404(DeliveryPartner, user=request.user)
        serializer = DeliveryPartnerStatusUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        partner = services.set_status(partner, serializer.validated_data["status"])
        return APIResponse(data=DeliveryPartnerProfileSerializer(partner).data)


@extend_schema(tags=["Delivery"], summary="List orders ready for pickup and not yet claimed by a partner")
class AvailableOrdersView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryPartner]

    def get(self, request):
        return paginated_response(request, self, services.available_orders_queryset(), OrderSerializer)


@extend_schema(tags=["Delivery"], summary="List the current partner's active and past deliveries")
class MyDeliveriesView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryPartner]

    def get(self, request):
        partner = get_object_or_404(DeliveryPartner, user=request.user)
        queryset = Order.objects.filter(delivery_partner=partner)
        status_filter = request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return paginated_response(request, self, queryset, OrderSerializer)


@extend_schema(tags=["Delivery"], summary="Claim an available order for delivery")
class AcceptOrderView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryPartner]

    def post(self, request, pk):
        partner = get_object_or_404(DeliveryPartner, user=request.user)
        order = get_object_or_404(Order, pk=pk)
        order = services.accept_order(order, partner)
        return APIResponse(data=OrderSerializer(order).data)


@extend_schema(tags=["Delivery"], summary="Mark an assigned order as delivered")
class MarkDeliveredView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsDeliveryPartner]

    def post(self, request, pk):
        partner = get_object_or_404(DeliveryPartner, user=request.user)
        order = get_object_or_404(Order, pk=pk)
        order = services.mark_delivered(order, partner)
        return APIResponse(data=OrderSerializer(order).data)


@extend_schema(tags=["Admin"], summary="List all delivery partners, optionally filtered by verification (admin only)")
class AdminDeliveryPartnerListView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def get(self, request):
        queryset = DeliveryPartner.objects.all().order_by("-created_at")
        is_verified = request.query_params.get("is_verified")
        if is_verified is not None:
            queryset = queryset.filter(is_verified=is_verified in ("true", "1"))
        return paginated_response(request, self, queryset, DeliveryPartnerProfileSerializer)


@extend_schema(tags=["Admin"], summary="Verify or unverify a delivery partner (admin only)")
class AdminDeliveryPartnerVerifyView(APIView):
    permission_classes = [permissions.IsAuthenticated, IsAdminRole]

    def post(self, request, pk):
        partner = get_object_or_404(DeliveryPartner, pk=pk)
        partner.is_verified = bool(request.data.get("is_verified", True))
        partner.save(update_fields=["is_verified"])
        return APIResponse(data=DeliveryPartnerProfileSerializer(partner).data)
