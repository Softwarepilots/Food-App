from django.db.models import F
from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.orders.models import Order, OrderStatus

from .models import DeliveryPartner


@receiver(post_save, sender=Order)
def increment_delivery_partner_stats(sender, instance, created, **kwargs):
    if created or instance.status != OrderStatus.DELIVERED or not instance.delivery_partner_id:
        return
    DeliveryPartner.objects.filter(pk=instance.delivery_partner_id).update(
        total_deliveries=F("total_deliveries") + 1
    )
