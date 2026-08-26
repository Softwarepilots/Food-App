from django.core.exceptions import ValidationError
from django.db.models.signals import pre_save
from django.dispatch import receiver

from .models import Cart, CartItem


@receiver(pre_save, sender=CartItem)
def enforce_single_restaurant_cart(sender, instance, **kwargs):
    """A cart can only hold items from one restaurant at a time. The first item
    added pins the cart to that restaurant; later items must match it."""
    cart = instance.cart
    food_restaurant_id = instance.food.restaurant_id

    if cart.restaurant_id is None:
        Cart.objects.filter(pk=cart.pk).update(restaurant_id=food_restaurant_id)
        cart.restaurant_id = food_restaurant_id
        return

    if cart.restaurant_id != food_restaurant_id:
        raise ValidationError("This cart already contains items from a different restaurant. Clear it first.")
