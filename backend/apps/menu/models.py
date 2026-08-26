from decimal import Decimal

from django.core.exceptions import ValidationError
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone

from apps.common.models import BaseModel
from apps.common.validators import rating_validators
from .validators import validate_gst_rate


class InventoryTrackingMixin(models.Model):
    """Shared stock-tracking fields for `Food` and `FoodVariant` — a variant
    (e.g. "Full" plate) can sell out independently of its parent food (e.g.
    "Half" plate might still be available), so both need their own stock."""

    track_inventory = models.BooleanField(default=False)
    stock_quantity = models.PositiveIntegerField(default=0)
    low_stock_threshold = models.PositiveIntegerField(default=5)

    class Meta:
        abstract = True

    @property
    def is_in_stock(self):
        return (not self.track_inventory) or self.stock_quantity > 0

    @property
    def is_low_stock(self):
        return self.track_inventory and 0 < self.stock_quantity <= self.low_stock_threshold


class FoodCategory(BaseModel):
    restaurant = models.ForeignKey(
        "restaurants.Restaurant", on_delete=models.CASCADE, related_name="food_categories"
    )
    name = models.CharField(max_length=100)
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        db_table = "menu_food_category"
        verbose_name = "Food Category"
        verbose_name_plural = "Food Categories"
        ordering = ["sort_order", "name"]
        constraints = [
            models.UniqueConstraint(
                fields=["restaurant", "name"],
                condition=models.Q(is_deleted=False),
                name="unique_category_name_per_restaurant",
            )
        ]
        indexes = [
            models.Index(fields=["restaurant", "sort_order"]),
        ]

    def __str__(self):
        return f"{self.name} ({self.restaurant.name})"


class FoodType(models.TextChoices):
    VEG = "veg", "Vegetarian"
    NON_VEG = "non_veg", "Non-Vegetarian"
    EGG = "egg", "Contains Egg"
    VEGAN = "vegan", "Vegan"


class Food(BaseModel, InventoryTrackingMixin):
    restaurant = models.ForeignKey("restaurants.Restaurant", on_delete=models.CASCADE, related_name="food_items")
    category = models.ForeignKey(
        FoodCategory, on_delete=models.SET_NULL, null=True, blank=True, related_name="food_items"
    )
    name = models.CharField(max_length=150)
    description = models.TextField(blank=True)
    base_price = models.DecimalField(max_digits=8, decimal_places=2, validators=[MinValueValidator(Decimal("0.01"))])
    gst_rate = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal("5.00"), validators=[validate_gst_rate])
    image_url = models.URLField(blank=True)
    food_type = models.CharField(max_length=10, choices=FoodType.choices, default=FoodType.VEG)
    is_available = models.BooleanField(default=True)
    is_bestseller = models.BooleanField(default=False)
    calories = models.PositiveIntegerField(null=True, blank=True)
    preparation_time_minutes = models.PositiveSmallIntegerField(default=15, validators=[MinValueValidator(1)])
    average_rating = models.DecimalField(max_digits=3, decimal_places=2, default=0, validators=rating_validators)
    total_reviews = models.PositiveIntegerField(default=0)

    class Meta:
        db_table = "menu_food"
        verbose_name = "Food"
        verbose_name_plural = "Food Items"
        ordering = ["name"]
        indexes = [
            models.Index(fields=["restaurant", "is_available"]),
            models.Index(fields=["food_type"]),
            models.Index(fields=["category"]),
        ]

    def __str__(self):
        return f"{self.name} - {self.restaurant.name}"

    @property
    def is_orderable(self):
        return self.is_available and self.is_in_stock


class FoodVariant(BaseModel, InventoryTrackingMixin):
    food = models.ForeignKey(Food, on_delete=models.CASCADE, related_name="variants")
    name = models.CharField(max_length=50)
    price = models.DecimalField(max_digits=8, decimal_places=2, validators=[MinValueValidator(Decimal("0.01"))])
    is_default = models.BooleanField(default=False)
    is_available = models.BooleanField(default=True)

    class Meta:
        db_table = "menu_food_variant"
        verbose_name = "Food Variant"
        verbose_name_plural = "Food Variants"
        ordering = ["price"]
        constraints = [
            models.UniqueConstraint(
                fields=["food", "name"],
                condition=models.Q(is_deleted=False),
                name="unique_variant_name_per_food",
            )
        ]
        indexes = [
            models.Index(fields=["food", "is_default"]),
        ]

    def __str__(self):
        return f"{self.food.name} - {self.name}"

    @property
    def is_orderable(self):
        return self.is_available and self.is_in_stock

    @property
    def restaurant(self):
        return self.food.restaurant


class FoodAddon(BaseModel):
    food = models.ForeignKey(Food, on_delete=models.CASCADE, related_name="addons")
    name = models.CharField(max_length=100)
    price = models.DecimalField(max_digits=6, decimal_places=2, validators=[MinValueValidator(Decimal("0"))])
    is_available = models.BooleanField(default=True)
    max_quantity = models.PositiveSmallIntegerField(default=1, validators=[MinValueValidator(1)])

    class Meta:
        db_table = "menu_food_addon"
        verbose_name = "Food Addon"
        verbose_name_plural = "Food Addons"
        ordering = ["name"]
        constraints = [
            models.UniqueConstraint(
                fields=["food", "name"],
                condition=models.Q(is_deleted=False),
                name="unique_addon_name_per_food",
            )
        ]
        indexes = [
            models.Index(fields=["food", "is_available"]),
        ]

    def __str__(self):
        return f"{self.food.name} - {self.name}"

    @property
    def restaurant(self):
        return self.food.restaurant


class FoodImage(BaseModel):
    food = models.ForeignKey(Food, on_delete=models.CASCADE, related_name="images")
    image_url = models.URLField()
    caption = models.CharField(max_length=150, blank=True)
    is_primary = models.BooleanField(default=False)
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        db_table = "menu_food_image"
        verbose_name = "Food Image"
        verbose_name_plural = "Food Images"
        ordering = ["sort_order", "created_at"]
        indexes = [
            models.Index(fields=["food", "is_primary"]),
        ]

    def __str__(self):
        return f"Image for {self.food.name}"

    @property
    def restaurant(self):
        return self.food.restaurant


class FoodDiscountType(models.TextChoices):
    PERCENTAGE = "percentage", "Percentage Off"
    FLAT = "flat", "Flat Amount Off"


class FoodDiscount(BaseModel):
    food = models.ForeignKey(Food, on_delete=models.CASCADE, related_name="discounts")
    discount_type = models.CharField(max_length=10, choices=FoodDiscountType.choices)
    value = models.DecimalField(max_digits=6, decimal_places=2, validators=[MinValueValidator(Decimal("0.01"))])
    max_discount_amount = models.DecimalField(
        max_digits=6, decimal_places=2, null=True, blank=True, validators=[MinValueValidator(Decimal("0"))]
    )
    valid_from = models.DateTimeField()
    valid_until = models.DateTimeField()
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = "menu_food_discount"
        verbose_name = "Food Discount"
        verbose_name_plural = "Food Discounts"
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["food", "is_active", "valid_from", "valid_until"]),
        ]

    def __str__(self):
        return f"{self.get_discount_type_display()} on {self.food.name}"

    def clean(self):
        if self.valid_until <= self.valid_from:
            raise ValidationError("valid_until must be after valid_from.")
        if self.discount_type == FoodDiscountType.PERCENTAGE and self.value > 100:
            raise ValidationError("Percentage discount cannot exceed 100.")

    def is_valid_now(self):
        now = timezone.now()
        return self.is_active and self.valid_from <= now <= self.valid_until

    @property
    def restaurant(self):
        return self.food.restaurant


class FoodReview(BaseModel):
    user = models.ForeignKey("accounts.User", on_delete=models.CASCADE, related_name="food_reviews")
    food = models.ForeignKey(Food, on_delete=models.CASCADE, related_name="reviews")
    rating = models.PositiveSmallIntegerField(validators=[MinValueValidator(1), MaxValueValidator(5)])
    comment = models.TextField(blank=True)

    class Meta:
        db_table = "menu_food_review"
        verbose_name = "Food Review"
        verbose_name_plural = "Food Reviews"
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["user", "food"],
                condition=models.Q(is_deleted=False),
                name="unique_food_review_per_user",
            )
        ]
        indexes = [
            models.Index(fields=["food", "rating"]),
        ]

    def __str__(self):
        return f"{self.rating}★ review of {self.food.name} by {self.user.full_name}"
