from django.db.models import Avg, Count
from django.db.models.signals import post_delete, post_save, pre_save
from django.dispatch import receiver
from django.utils import timezone

from .models import Order, OrderStatus, Review

_STATUS_MESSAGES = {
    OrderStatus.PLACED: "Your order has been placed.",
    OrderStatus.ACCEPTED: "The restaurant has accepted your order.",
    OrderStatus.PREPARING: "Your food is being prepared.",
    OrderStatus.READY_FOR_PICKUP: "Your order is ready for pickup.",
    OrderStatus.OUT_FOR_DELIVERY: "Your order is out for delivery.",
    OrderStatus.DELIVERED: "Your order has been delivered. Enjoy!",
    OrderStatus.CANCELLED: "Your order has been cancelled.",
}


@receiver(pre_save, sender=Order)
def generate_order_number(sender, instance, **kwargs):
    if instance.order_number:
        return
    instance.order_number = f"ORD{timezone.now():%Y%m%d}{str(instance.id).replace('-', '')[:8].upper()}"


@receiver(pre_save, sender=Order)
def _capture_previous_status(sender, instance, **kwargs):
    if not instance.pk:
        instance._previous_status = None
        return
    previous = Order.all_objects.filter(pk=instance.pk).values_list("status", flat=True).first()
    instance._previous_status = previous


@receiver(post_save, sender=Order)
def notify_on_status_change(sender, instance, created, **kwargs):
    from apps.notifications.models import Notification, NotificationType

    previous_status = getattr(instance, "_previous_status", None)
    if not created and previous_status == instance.status:
        return

    Notification.objects.create(
        user_id=instance.user_id,
        notification_type=NotificationType.ORDER_UPDATE,
        title=f"Order {instance.order_number}",
        body=_STATUS_MESSAGES.get(instance.status, "Your order status has been updated."),
        order_id=instance.id,
    )


def _recompute_restaurant_rating(restaurant_id):
    from apps.restaurants.models import Restaurant

    aggregate = Review.objects.filter(restaurant_id=restaurant_id).aggregate(
        avg_rating=Avg("rating"), review_count=Count("id")
    )
    Restaurant.objects.filter(pk=restaurant_id).update(
        average_rating=aggregate["avg_rating"] or 0,
        total_reviews=aggregate["review_count"] or 0,
    )


@receiver(post_save, sender=Review)
def update_restaurant_rating_on_save(sender, instance, **kwargs):
    _recompute_restaurant_rating(instance.restaurant_id)


@receiver(post_delete, sender=Review)
def update_restaurant_rating_on_delete(sender, instance, **kwargs):
    _recompute_restaurant_rating(instance.restaurant_id)
