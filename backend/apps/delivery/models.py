from decimal import Decimal

from django.core.exceptions import ValidationError
from django.core.validators import MinValueValidator
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


class DeliveryShift(BaseModel):
    """A bookable work slot — Swiggy-style "gigs": a rider commits to a time
    window upfront for an hourly rate range, rather than just picking up
    whatever ad-hoc orders appear. Grouped client-side into Lunch/Evening/
    Dinner sessions by `start_time` — not its own field, since the three
    windows are fixed (11-3, 3-7, 7-12) and deriving it avoids a second
    source of truth that could drift from the actual time."""

    date = models.DateField(db_index=True)
    start_time = models.TimeField()
    end_time = models.TimeField()
    rate_min_per_hour = models.DecimalField(max_digits=8, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    rate_max_per_hour = models.DecimalField(max_digits=8, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    capacity = models.PositiveSmallIntegerField(validators=[MinValueValidator(1)])
    # Marks a particularly high-demand slot worth highlighting (the star
    # badge in the UI) — set by whoever schedules gigs, not computed.
    is_peak = models.BooleanField(default=False)

    class Meta:
        db_table = "delivery_shift"
        verbose_name = "Delivery Shift"
        verbose_name_plural = "Delivery Shifts"
        ordering = ["date", "start_time"]
        indexes = [models.Index(fields=["date", "start_time"])]

    def __str__(self):
        return f"{self.date} {self.start_time}-{self.end_time}"

    def clean(self):
        if self.end_time <= self.start_time:
            raise ValidationError("end_time must be after start_time.")
        if self.rate_max_per_hour < self.rate_min_per_hour:
            raise ValidationError("rate_max_per_hour must be >= rate_min_per_hour.")


class ShiftBookingStatus(models.TextChoices):
    BOOKED = "booked", "Booked"
    CANCELLED = "cancelled", "Cancelled"
    COMPLETED = "completed", "Completed"
    NO_SHOW = "no_show", "No Show"


class ShiftBooking(BaseModel):
    shift = models.ForeignKey(DeliveryShift, on_delete=models.CASCADE, related_name="bookings")
    delivery_partner = models.ForeignKey(DeliveryPartner, on_delete=models.CASCADE, related_name="shift_bookings")
    status = models.CharField(max_length=10, choices=ShiftBookingStatus.choices, default=ShiftBookingStatus.BOOKED)

    class Meta:
        db_table = "delivery_shift_booking"
        verbose_name = "Shift Booking"
        verbose_name_plural = "Shift Bookings"
        ordering = ["-created_at"]
        constraints = [
            # One booking row per (shift, partner) ever — cancelling flips
            # status back to CANCELLED rather than deleting the row, and
            # rebooking flips the same row back to BOOKED, so there's never
            # ambiguity about which row represents "the" booking.
            models.UniqueConstraint(fields=["shift", "delivery_partner"], name="unique_shift_partner_booking"),
        ]
        indexes = [models.Index(fields=["delivery_partner", "status"])]

    def __str__(self):
        return f"{self.delivery_partner.user.full_name} - {self.shift}"
