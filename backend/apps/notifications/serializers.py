from rest_framework import serializers

from .models import DevicePlatform, Notification


class DeviceTokenRegisterSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=255)
    platform = serializers.ChoiceField(choices=DevicePlatform.choices)


class DeviceTokenUnregisterSerializer(serializers.Serializer):
    token = serializers.CharField(max_length=255)


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ("id", "notification_type", "title", "body", "order", "is_read", "created_at")
