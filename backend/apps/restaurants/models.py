from decimal import Decimal

from django.contrib.postgres.fields import ArrayField
from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone
from django.utils.text import slugify

from apps.accounts.models import UserRole
from apps.common.models import BaseModel
from apps.common.validators import latitude_validators, longitude_validators, percentage_validators, rating_validators


class RestaurantCategory(BaseModel):
    """Admin-curated restaurant classification (e.g. "Fast Food", "Fine Dining"),
    distinct from `Restaurant.cuisine_tags` (free-text) and from `menu.FoodCategory`
    (per-restaurant menu grouping). Used to power category filter chips."""

    name = models.CharField(max_length=80, unique=True)
    slug = models.SlugField(max_length=100, unique=True, blank=True)
    icon_url = models.URLField(blank=True)
    is_active = models.BooleanField(default=True)
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        db_table = "restaurants_category"
        verbose_name = "Restaurant Category"
        verbose_name_plural = "Restaurant Categories"
        ordering = ["sort_order", "name"]
        indexes = [
            models.Index(fields=["is_active", "sort_order"]),
        ]

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.slug:
            self.slug = slugify(self.name)[:100]
        super().save(*args, **kwargs)


class RestaurantApprovalStatus(models.TextChoices):
    PENDING = "pending", "Pending Approval"
    APPROVED = "approved", "Approved"
    REJECTED = "rejected", "Rejected"


class Restaurant(BaseModel):
    owner = models.ForeignKey(
        "accounts.User",
        on_delete=models.CASCADE,
        related_name="restaurants",
        limit_choices_to={"role": UserRole.RESTAURANT_OWNER},
    )
    name = models.CharField(max_length=150)
    slug = models.SlugField(max_length=170, unique=True, blank=True)
    description = models.TextField(blank=True)
    cover_image_url = models.URLField(blank=True)
    cuisine_tags = ArrayField(models.CharField(max_length=50), default=list, blank=True)
    categories = models.ManyToManyField(RestaurantCategory, blank=True, related_name="restaurants")
    address_line = models.CharField(max_length=255)
    city = models.CharField(max_length=100, db_index=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, validators=latitude_validators)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, validators=longitude_validators)
    delivery_radius_km = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=Decimal("5.00"),
        validators=[MinValueValidator(Decimal("0.5")), MaxValueValidator(Decimal("50"))],
    )
    is_active = models.BooleanField(default=True)
    is_accepting_orders = models.BooleanField(default=True)
    avg_prep_time_minutes = models.PositiveSmallIntegerField(
        default=30, validators=[MinValueValidator(5), MaxValueValidator(180)]
    )
    average_rating = models.DecimalField(max_digits=3, decimal_places=2, default=0, validators=rating_validators)
    total_reviews = models.PositiveIntegerField(default=0)

    approval_status = models.CharField(
        max_length=10, choices=RestaurantApprovalStatus.choices, default=RestaurantApprovalStatus.PENDING, db_index=True
    )
    rejection_reason = models.CharField(max_length=255, blank=True)
    approved_at = models.DateTimeField(null=True, blank=True)
    approved_by = models.ForeignKey(
        "accounts.User", on_delete=models.SET_NULL, null=True, blank=True, related_name="approved_restaurants"
    )

    class Meta:
        db_table = "restaurants_restaurant"
        verbose_name = "Restaurant"
        verbose_name_plural = "Restaurants"
        ordering = ["-average_rating", "-created_at"]
        indexes = [
            models.Index(fields=["latitude", "longitude"]),
            models.Index(fields=["city", "is_active"]),
            models.Index(fields=["is_active", "is_accepting_orders"]),
            models.Index(fields=["approval_status"]),
        ]

    def __str__(self):
        return self.name

    def save(self, *args, **kwargs):
        if not self.slug:
            base_slug = slugify(self.name)[:150]
            slug_candidate = base_slug
            suffix = 1
            while Restaurant.all_objects.filter(slug=slug_candidate).exclude(pk=self.pk).exists():
                suffix += 1
                slug_candidate = f"{base_slug}-{suffix}"
            self.slug = slug_candidate
        super().save(*args, **kwargs)

    @property
    def is_open_now(self):
        now = timezone.localtime()
        hours = self.business_hours.filter(day_of_week=now.weekday()).first()
        if hours is None or hours.is_closed:
            return False
        current_time = now.time()
        if hours.opening_time <= hours.closing_time:
            return hours.opening_time <= current_time <= hours.closing_time
        return current_time >= hours.opening_time or current_time <= hours.closing_time

    @property
    def is_orderable(self):
        return (
            self.approval_status == RestaurantApprovalStatus.APPROVED
            and self.is_active
            and self.is_accepting_orders
            and self.is_open_now
        )

    @property
    def display_status(self):
        if self.approval_status != RestaurantApprovalStatus.APPROVED:
            return self.approval_status
        if not self.is_active:
            return "inactive"
        if not self.is_accepting_orders:
            return "paused"
        if not self.is_open_now:
            return "closed"
        return "open"


class DayOfWeek(models.IntegerChoices):
    """Matches Python's `date.weekday()`: Monday=0 .. Sunday=6."""

    MONDAY = 0, "Monday"
    TUESDAY = 1, "Tuesday"
    WEDNESDAY = 2, "Wednesday"
    THURSDAY = 3, "Thursday"
    FRIDAY = 4, "Friday"
    SATURDAY = 5, "Saturday"
    SUNDAY = 6, "Sunday"


class RestaurantBusinessHours(BaseModel):
    restaurant = models.ForeignKey(Restaurant, on_delete=models.CASCADE, related_name="business_hours")
    day_of_week = models.PositiveSmallIntegerField(choices=DayOfWeek.choices)
    opening_time = models.TimeField(null=True, blank=True)
    closing_time = models.TimeField(null=True, blank=True)
    is_closed = models.BooleanField(default=False)

    class Meta:
        db_table = "restaurants_business_hours"
        verbose_name = "Business Hours"
        verbose_name_plural = "Business Hours"
        ordering = ["day_of_week"]
        constraints = [
            models.UniqueConstraint(
                fields=["restaurant", "day_of_week"],
                condition=models.Q(is_deleted=False),
                name="unique_business_hours_per_day",
            )
        ]

    def __str__(self):
        return f"{self.restaurant.name} - {self.get_day_of_week_display()}"

    def clean(self):
        if not self.is_closed and (self.opening_time is None or self.closing_time is None):
            raise ValidationError("opening_time and closing_time are required unless the day is marked closed.")
        if not self.is_closed and self.opening_time == self.closing_time:
            raise ValidationError("closing_time cannot equal opening_time.")


class RestaurantImage(BaseModel):
    restaurant = models.ForeignKey(Restaurant, on_delete=models.CASCADE, related_name="images")
    image_url = models.URLField()
    caption = models.CharField(max_length=150, blank=True)
    is_primary = models.BooleanField(default=False)
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        db_table = "restaurants_restaurant_image"
        verbose_name = "Restaurant Image"
        verbose_name_plural = "Restaurant Images"
        ordering = ["sort_order", "created_at"]
        indexes = [
            models.Index(fields=["restaurant", "is_primary"]),
        ]

    def __str__(self):
        return f"Image for {self.restaurant.name}"


class RestaurantDocumentType(models.TextChoices):
    FSSAI_LICENSE = "fssai_license", "FSSAI License"
    GST_CERTIFICATE = "gst_certificate", "GST Certificate"
    PAN_CARD = "pan_card", "PAN Card"
    BUSINESS_LICENSE = "business_license", "Business License"
    OTHER = "other", "Other"


class RestaurantDocumentStatus(models.TextChoices):
    PENDING = "pending", "Pending Review"
    VERIFIED = "verified", "Verified"
    REJECTED = "rejected", "Rejected"


class RestaurantDocument(BaseModel):
    restaurant = models.ForeignKey(Restaurant, on_delete=models.CASCADE, related_name="documents")
    document_type = models.CharField(max_length=20, choices=RestaurantDocumentType.choices)
    file_url = models.URLField()
    status = models.CharField(
        max_length=10, choices=RestaurantDocumentStatus.choices, default=RestaurantDocumentStatus.PENDING, db_index=True
    )
    rejection_reason = models.CharField(max_length=255, blank=True)
    reviewed_by = models.ForeignKey(
        "accounts.User", on_delete=models.SET_NULL, null=True, blank=True, related_name="reviewed_documents"
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        db_table = "restaurants_document"
        verbose_name = "Restaurant Document"
        verbose_name_plural = "Restaurant Documents"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["restaurant", "document_type"]),
            models.Index(fields=["status"]),
        ]

    def __str__(self):
        return f"{self.get_document_type_display()} - {self.restaurant.name}"


class Favorite(BaseModel):
    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="favorites")
    restaurant = models.ForeignKey(Restaurant, on_delete=models.CASCADE, related_name="favorited_by")

    class Meta:
        db_table = "restaurants_favorite"
        verbose_name = "Favorite"
        verbose_name_plural = "Favorites"
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "restaurant"],
                condition=models.Q(is_deleted=False),
                name="unique_active_favorite",
            )
        ]
        indexes = [
            models.Index(fields=["user"]),
        ]

    def __str__(self):
        return f"{self.user.full_name} ❤ {self.restaurant.name}"


class OfferType(models.TextChoices):
    PERCENTAGE = "percentage", "Percentage Off"
    FLAT = "flat", "Flat Amount Off"
    FREE_DELIVERY = "free_delivery", "Free Delivery"


class Offer(BaseModel):
    restaurant = models.ForeignKey(
        Restaurant, on_delete=models.CASCADE, related_name="offers", null=True, blank=True
    )
    title = models.CharField(max_length=150)
    description = models.TextField(blank=True)
    offer_type = models.CharField(max_length=20, choices=OfferType.choices)
    discount_percentage = models.DecimalField(
        max_digits=5, decimal_places=2, null=True, blank=True, validators=percentage_validators
    )
    discount_amount = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(Decimal("0"))]
    )
    max_discount_amount = models.DecimalField(
        max_digits=8, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(Decimal("0"))]
    )
    min_order_value = models.DecimalField(max_digits=8, decimal_places=2, default=0, validators=[MinValueValidator(Decimal("0"))])
    valid_from = models.DateTimeField()
    valid_until = models.DateTimeField()
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "restaurants_offer"
        verbose_name = "Offer"
        verbose_name_plural = "Offers"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["is_active", "valid_from", "valid_until"]),
            models.Index(fields=["restaurant", "is_active"]),
        ]

    def __str__(self):
        return self.title

    def clean(self):
        if self.valid_until <= self.valid_from:
            raise ValidationError("valid_until must be after valid_from.")
        if self.offer_type == OfferType.PERCENTAGE and not self.discount_percentage:
            raise ValidationError("discount_percentage is required for percentage offers.")
        if self.offer_type == OfferType.FLAT and not self.discount_amount:
            raise ValidationError("discount_amount is required for flat offers.")

    def is_valid_now(self):
        now = timezone.now()
        return self.is_active and self.valid_from <= now <= self.valid_until
