from django.shortcuts import get_object_or_404
from drf_spectacular.utils import extend_schema
from rest_framework import permissions
from rest_framework.views import APIView

from apps.common.pagination import paginated_response
from apps.common.response import APIResponse

from . import services
from .models import Notification
from .serializers import DeviceTokenRegisterSerializer, DeviceTokenUnregisterSerializer, NotificationSerializer


@extend_schema(tags=["Notifications"], summary="Register this device's FCM token for push notifications")
class DeviceTokenRegisterView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenRegisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.register_device_token(request.user, **serializer.validated_data)
        return APIResponse(data={"registered": True})


@extend_schema(tags=["Notifications"], summary="Unregister this device's FCM token (e.g. on logout)")
class DeviceTokenUnregisterView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = DeviceTokenUnregisterSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        services.unregister_device_token(request.user, **serializer.validated_data)
        return APIResponse(data={"unregistered": True})


@extend_schema(tags=["Notifications"], summary="List the current user's notifications, most recent first")
class NotificationListView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        queryset = Notification.objects.filter(user=request.user)
        return paginated_response(request, self, queryset, NotificationSerializer)


@extend_schema(tags=["Notifications"], summary="Mark one notification as read")
class NotificationMarkReadView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        notification = get_object_or_404(Notification, pk=pk, user=request.user)
        notification.mark_as_read()
        return APIResponse(data=NotificationSerializer(notification).data)
