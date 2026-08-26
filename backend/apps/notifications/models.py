from django.db import models
from django.utils import timezone

from apps.common.models import BaseModel


class NotificationType(models.TextChoices):
    ORDER_UPDATE = "order_update", "Order Update"
    PROMOTION = "promotion", "Promotion"
    PAYMENT = "payment", "Payment"
    DELIVERY = "delivery", "Delivery"
    SYSTEM = "system", "System"


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
