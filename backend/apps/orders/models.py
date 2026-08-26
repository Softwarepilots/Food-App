from decimal import Decimal

from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone

from apps.common.models import BaseModel
from apps.common.validators import coupon_code_validator, latitude_validators, longitude_validators


class CouponDiscountType(models.TextChoices):
    PERCENTAGE = "percentage", "Percentage"
    FLAT = "flat", "Flat Amount"


class Coupon(BaseModel):
    code = models.CharField(max_length=30, unique=True, validators=[coupon_code_validator])
    description = models.CharField(max_length=255, blank=True)
    discount_type = models.CharField(max_length=10, choices=CouponDiscountType.choices)
    discount_value = models.DecimalField(max_digits=8, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    max_discount_amount = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(Decimal("0"))]
    )
    min_order_value = models.DecimalField(max_digits=8, decimal_places=2, default=0, validators=[MinValueValidator(Decimal("0"))])
    usage_limit_per_user = models.PositiveSmallIntegerField(default=1, validators=[MinValueValidator(1)])
    total_usage_limit = models.PositiveIntegerField(null=True, blank=True)
    times_used = models.PositiveIntegerField(default=0)
    valid_from = models.DateTimeField()
    valid_until = models.DateTimeField()
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "orders_coupon"
        verbose_name = "Coupon"
        verbose_name_plural = "Coupons"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["code", "is_active"]),
        ]

    def __str__(self):
        return self.code

    def clean(self):
        if self.valid_until <= self.valid_from:
            raise ValidationError("valid_until must be after valid_from.")
        if self.discount_type == CouponDiscountType.PERCENTAGE and self.discount_value > 100:
            raise ValidationError("Percentage discount cannot exceed 100.")

    def save(self, *args, **kwargs):
        self.code = self.code.upper()
        super().save(*args, **kwargs)

    def is_valid_now(self):
        now = timezone.now()
        if not self.is_active or not (self.valid_from <= now <= self.valid_until):
            return False
        if self.total_usage_limit is not None and self.times_used >= self.total_usage_limit:
            return False
        return True


class OrderStatus(models.TextChoices):
    PLACED = "placed", "Placed"
    ACCEPTED = "accepted", "Accepted"
    PREPARING = "preparing", "Preparing"
    READY_FOR_PICKUP = "ready_for_pickup", "Ready for Pickup"
    OUT_FOR_DELIVERY = "out_for_delivery", "Out for Delivery"
    DELIVERED = "delivered", "Delivered"
    CANCELLED = "cancelled", "Cancelled"


class OrderPaymentStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    PAID = "paid", "Paid"
    FAILED = "failed", "Failed"
    REFUNDED = "refunded", "Refunded"


class Order(BaseModel):
    order_number = models.CharField(max_length=20, unique=True, editable=False, blank=True)
    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="orders")
    restaurant = models.ForeignKey("restaurants.Restaurant", on_delete=models.CASCADE, related_name="orders")
    delivery_partner = models.ForeignKey(
        "delivery.DeliveryPartner", on_delete=models.SET_NULL, null=True, blank=True, related_name="orders"
    )
    coupon = models.ForeignKey(Coupon, on_delete=models.SET_NULL, null=True, blank=True, related_name="orders")

    delivery_address_text = models.TextField()
    delivery_latitude = models.DecimalField(max_digits=9, decimal_places=6, validators=latitude_validators)
    delivery_longitude = models.DecimalField(max_digits=9, decimal_places=6, validators=longitude_validators)
    notes = models.TextField(blank=True)

    status = models.CharField(max_length=20, choices=OrderStatus.choices, default=OrderStatus.PLACED, db_index=True)
    payment_status = models.CharField(
        max_length=10, choices=OrderPaymentStatus.choices, default=OrderPaymentStatus.PENDING, db_index=True
    )

    subtotal = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    delivery_fee = models.DecimalField(max_digits=8, decimal_places=2, default=0, validators=[MinValueValidator(Decimal("0"))])
    tax_amount = models.DecimalField(max_digits=8, decimal_places=2, default=0, validators=[MinValueValidator(Decimal("0"))])
    discount_amount = models.DecimalField(max_digits=8, decimal_places=2, default=0, validators=[MinValueValidator(Decimal("0"))])
    total_amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])

    cancellation_reason = models.CharField(max_length=255, blank=True)
    accepted_at = models.DateTimeField(null=True, blank=True)
    delivered_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "orders_order"
        verbose_name = "Order"
        verbose_name_plural = "Orders"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["user", "status"]),
            models.Index(fields=["restaurant", "status"]),
            models.Index(fields=["delivery_partner", "status"]),
            models.Index(fields=["order_number"]),
        ]

    def __str__(self):
        return self.order_number or str(self.id)

    def clean(self):
        expected_total = self.subtotal + self.delivery_fee + self.tax_amount - self.discount_amount
        if self.total_amount != expected_total:
            raise ValidationError("total_amount must equal subtotal + delivery_fee + tax_amount - discount_amount.")


class OrderItem(BaseModel):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="items")
    food = models.ForeignKey("menu.Food", on_delete=models.SET_NULL, null=True, related_name="order_items")
    variant = models.ForeignKey(
        "menu.FoodVariant", on_delete=models.SET_NULL, null=True, blank=True, related_name="order_items"
    )
    food_name_snapshot = models.CharField(max_length=150)
    variant_name_snapshot = models.CharField(max_length=50, blank=True)
    unit_price_snapshot = models.DecimalField(max_digits=8, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    quantity = models.PositiveSmallIntegerField(validators=[MinValueValidator(1)])
    addons_snapshot = models.JSONField(default=list, blank=True)
    line_total = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    notes = models.CharField(max_length=255, blank=True)

    class Meta:
        db_table = "orders_order_item"
        verbose_name = "Order Item"
        verbose_name_plural = "Order Items"
        indexes = [
            models.Index(fields=["order"]),
        ]

    def __str__(self):
        return f"{self.quantity} x {self.food_name_snapshot}"


class Review(BaseModel):
    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="reviews")
    restaurant = models.ForeignKey("restaurants.Restaurant", on_delete=models.CASCADE, related_name="reviews")
    order = models.ForeignKey(Order, on_delete=models.SET_NULL, null=True, blank=True, related_name="review")
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True)
    restaurant_reply = models.TextField(blank=True)

    class Meta:
        db_table = "orders_review"
        verbose_name = "Review"
        verbose_name_plural = "Reviews"
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "order"],
                condition=models.Q(is_deleted=False, order__isnull=False),
                name="unique_review_per_order",
            )
        ]
        indexes = [
            models.Index(fields=["restaurant", "rating"]),
        ]

    def __str__(self):
        return f"{self.rating}★ review of {self.restaurant.name} by {self.user.full_name}"
