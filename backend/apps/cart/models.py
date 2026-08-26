from decimal import Decimal

from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from apps.common.models import BaseModel


class Cart(BaseModel):
    user = models.OneToOneField("accounts.User", on_delete=models.CASCADE, related_name="cart")
    restaurant = models.ForeignKey(
        "restaurants.Restaurant", on_delete=models.SET_NULL, null=True, blank=True, related_name="carts"
    )

    class Meta:
        db_table = "cart_cart"
        verbose_name = "Cart"
        verbose_name_plural = "Carts"

    def __str__(self):
        return f"Cart of {self.user.full_name}"

    @property
    def subtotal(self):
        return sum((item.line_total for item in self.items.all()), Decimal("0.00"))

    def clear(self):
        self.items.all().delete()
        self.restaurant = None
        self.save(update_fields=["restaurant"])


class CartItem(BaseModel):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name="items")
    food = models.ForeignKey("menu.Food", on_delete=models.CASCADE, related_name="cart_items")
    variant = models.ForeignKey(
        "menu.FoodVariant", on_delete=models.SET_NULL, null=True, blank=True, related_name="cart_items"
    )
    addons = models.ManyToManyField("menu.FoodAddon", blank=True, related_name="cart_items")
    quantity = models.PositiveSmallIntegerField(default=1, validators=[MinValueValidator(1), MaxValueValidator(20)])
    notes = models.CharField(max_length=255, blank=True)

    class Meta:
        db_table = "cart_cart_item"
        verbose_name = "Cart Item"
        verbose_name_plural = "Cart Items"
        ordering = ["created_at"]
        # NULL is never equal to NULL in a Postgres unique constraint, so two rows with the
        # same food and variant=NULL both satisfy this constraint — the service layer must
        # still merge/increment matching no-variant lines instead of relying on the DB alone.
        constraints = [
            models.UniqueConstraint(
                fields=["cart", "food", "variant"],
                condition=models.Q(is_deleted=False),
                name="unique_cart_line_item",
            )
        ]
        indexes = [
            models.Index(fields=["cart"]),
        ]

    def __str__(self):
        return f"{self.quantity} x {self.food.name}"

    @property
    def unit_price(self):
        return self.variant.price if self.variant_id else self.food.base_price

    @property
    def line_total(self):
        addon_total = sum((addon.price for addon in self.addons.all()), Decimal("0.00"))
        return (self.unit_price + addon_total) * self.quantity
