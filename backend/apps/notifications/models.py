from django.db import models
from django.utils import timezone

from apps.common.models import BaseModel


class NotificationType(models.TextChoices):
    ORDER_UPDATE = "order_update", "Order Update"
    PROMOTION = "promotion", "Promotion"
    PAYMENT = "payment", "Payment"
    DELIVERY = "delivery", "Delivery"
    SYSTEM = "system", "System"


class DevicePlatform(models.TextChoices):
    ANDROID = "android", "Android"
    IOS = "ios", "iOS"
    WEB = "web", "Web"


class DeviceToken(BaseModel):
    """One row per (user, device) FCM registration token. A user can be
    logged in on several devices/apps at once, so this isn't unique on user
    alone — but the token itself is, since FCM issues a fresh one per
    app-install and the old token becomes worthless the moment that happens."""

    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="device_tokens")
    token = models.CharField(max_length=255, unique=True)
    platform = models.CharField(max_length=10, choices=DevicePlatform.choices)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "notifications_device_token"
        verbose_name = "Device Token"
        verbose_name_plural = "Device Tokens"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "is_active"]),
        ]

    def __str__(self):
        return f"{self.user.full_name} ({self.platform})"


class Notification(BaseModel):
    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="notifications")
    notification_type = models.CharField(max_length=15, choices=NotificationType.choices, default=NotificationType.SYSTEM)
    title = models.CharField(max_length=150)
    body = models.CharField(max_length=500)
    order = models.ForeignKey(
        "orders.Order", on_delete=models.SET_NULL, null=True, blank=True, related_name="notifications"
    )
    is_read = models.BooleanField(default=False, db_index=True)
    read_at = models.DateTimeField(null=True, blank=True)
    fcm_response = models.JSONField(null=True, blank=True)

    class Meta:
        db_table = "notifications_notification"
        verbose_name = "Notification"
        verbose_name_plural = "Notifications"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "is_read"]),
        ]

    def __str__(self):
        return self.title

    def mark_as_read(self):
        if self.is_read:
            return
        self.is_read = True
        self.read_at = timezone.now()
        self.save(update_fields=["is_read", "read_at"])
