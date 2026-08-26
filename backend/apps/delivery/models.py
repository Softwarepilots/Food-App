from django.core.exceptions import ValidationError
from django.db import models

from apps.accounts.models import UserRole
from apps.common.models import BaseModel
from apps.common.validators import (
    latitude_validators,
    license_number_validator,
    longitude_validators,
    rating_validators,
    vehicle_number_validator,
)


class VehicleType(models.TextChoices):
    BICYCLE = "bicycle", "Bicycle"
    MOTORCYCLE = "motorcycle", "Motorcycle"
    SCOOTER = "scooter", "Scooter"
    CAR = "car", "Car"


class DeliveryPartnerStatus(models.TextChoices):
    OFFLINE = "offline", "Offline"
    ONLINE = "online", "Online"
    ON_DELIVERY = "on_delivery", "On Delivery"


class DeliveryPartner(BaseModel):
    user = models.OneToOneField(
        "accounts.User",
        on_delete=models.CASCADE,
        related_name="delivery_partner_profile",
        limit_choices_to={"role": UserRole.DELIVERY_PARTNER},
    )
    vehicle_type = models.CharField(max_length=15, choices=VehicleType.choices)
    vehicle_number = models.CharField(max_length=20, validators=[vehicle_number_validator])
    license_number = models.CharField(max_length=30, validators=[license_number_validator])
    status = models.CharField(
        max_length=15, choices=DeliveryPartnerStatus.choices, default=DeliveryPartnerStatus.OFFLINE, db_index=True
    )
    current_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True, validators=latitude_validators)
    current_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True, validators=longitude_validators)
    last_location_update_at = models.DateTimeField(null=True, blank=True)
    is_verified = models.BooleanField(default=False)
    rating_avg = models.DecimalField(max_digits=3, decimal_places=2, default=0, validators=rating_validators)
    total_deliveries = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = "delivery_delivery_partner"
        verbose_name = "Delivery Partner"
        verbose_name_plural = "Delivery Partners"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status"]),
            models.Index(fields=["current_latitude", "current_longitude"]),
        ]

    def __str__(self):
        return f"{self.user.full_name} ({self.get_status_display()})"

    def clean(self):
        if self.user_id and self.user.role != UserRole.DELIVERY_PARTNER:
            raise ValidationError("Linked user must have the delivery_partner role.")
