from django.db.models import Avg, Count
from django.db.models.signals import post_delete, post_save, pre_save
from django.dispatch import receiver
from django.utils import timezone

from .models import Order, Review


@receiver(pre_save, sender=Order)
def generate_order_number(sender, instance, **kwargs):
    if instance.order_number:
        return
    instance.order_number = f"ORD{timezone.now():%Y%m%d}{str(instance.id).replace('-', '')[:8].upper()}"


@receiver(post_save, sender=Order)
def notify_on_order_placed(sender, instance, created, **kwargs):
    """Order-placed confirmation only — every status-change notification
    (accepted/preparing/ready/out-for-delivery/delivered/cancelled) is
    handled explicitly, with push, by apps.orders.services and
    apps.delivery.services. Keeping both would double up in-app notification
    rows for the same event."""
    if not created:
        return

    from apps.notifications.models import Notification, NotificationType

    Notification.objects.create(
        user_id=instance.user_id,
        notification_type=NotificationType.ORDER_UPDATE,
        title=f"Order {instance.order_number}",
        body="Your order has been placed.",
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


def _recompute_delivery_partner_rating(delivery_partner_id):
    from apps.delivery.models import DeliveryPartner

    if delivery_partner_id is None:
        return
    aggregate = Review.objects.filter(delivery_partner_id=delivery_partner_id, delivery_rating__isnull=False).aggregate(
        avg_rating=Avg("delivery_rating")
    )
    DeliveryPartner.objects.filter(pk=delivery_partner_id).update(rating_avg=aggregate["avg_rating"] or 0)


@receiver(post_save, sender=Review)
def update_ratings_on_save(sender, instance, **kwargs):
    _recompute_restaurant_rating(instance.restaurant_id)
    _recompute_delivery_partner_rating(instance.delivery_partner_id)


@receiver(post_delete, sender=Review)
def update_ratings_on_delete(sender, instance, **kwargs):
    _recompute_restaurant_rating(instance.restaurant_id)
    _recompute_delivery_partner_rating(instance.delivery_partner_id)
