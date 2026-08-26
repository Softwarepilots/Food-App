import logging

from django.db.models import Avg, Count
from django.db.models.signals import post_delete, post_save, pre_save
from django.dispatch import receiver

from . import services
from .models import Food, FoodImage, FoodReview, FoodVariant

logger = logging.getLogger("apps")


@receiver(pre_save, sender=FoodVariant)
def enforce_single_default_variant(sender, instance, **kwargs):
    """A food item may have many variants but at most one marked `is_default`."""
    if not instance.is_default:
        return
    FoodVariant.objects.filter(food_id=instance.food_id, is_default=True).exclude(pk=instance.pk).update(
        is_default=False
    )


@receiver(pre_save, sender=FoodImage)
def enforce_single_primary_image(sender, instance, **kwargs):
    """A food item may have many images but at most one marked `is_primary`."""
    if not instance.is_primary:
        return
    FoodImage.objects.filter(food_id=instance.food_id, is_primary=True).exclude(pk=instance.pk).update(
        is_primary=False
    )


def _notify_owner_of_stock_status(item, status):
    from apps.notifications.models import Notification, NotificationType

    if status == "out_of_stock":
        body = f"{item.name} is now out of stock and has been hidden from the menu."
    elif status == "low_stock":
        body = f"{item.name} is running low on stock ({item.stock_quantity} left)."
    else:
        return

    Notification.objects.create(
        user_id=item.restaurant.owner_id,
        notification_type=NotificationType.SYSTEM,
        title="Inventory alert",
        body=body,
    )


def _recompute_food_rating(food_id):
    aggregate = FoodReview.objects.filter(food_id=food_id).aggregate(avg_rating=Avg("rating"), review_count=Count("id"))
    Food.objects.filter(pk=food_id).update(
        average_rating=aggregate["avg_rating"] or 0,
        total_reviews=aggregate["review_count"] or 0,
    )


@receiver(post_save, sender=FoodReview)
def update_food_rating_on_save(sender, instance, **kwargs):
    _recompute_food_rating(instance.food_id)


@receiver(post_delete, sender=FoodReview)
def update_food_rating_on_delete(sender, instance, **kwargs):
    _recompute_food_rating(instance.food_id)


@receiver(post_save, sender="orders.OrderItem")
def decrement_stock_on_order_item(sender, instance, created, **kwargs):
    """Inventory actually moves here: placing an order decrements stock on the
    ordered food (and its variant, if tracked independently)."""
    if not created:
        return

    if instance.variant_id and instance.variant.track_inventory:
        status = services.adjust_stock(instance.variant, -instance.quantity)
        _notify_owner_of_stock_status(instance.variant, status)

    if instance.food_id and instance.food.track_inventory:
        status = services.adjust_stock(instance.food, -instance.quantity)
        _notify_owner_of_stock_status(instance.food, status)
