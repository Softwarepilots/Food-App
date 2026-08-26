from django.db.models.signals import post_save
from django.dispatch import receiver

from apps.accounts.models import User

from .models import Payment, PaymentGatewayStatus, Wallet


@receiver(post_save, sender=User)
def create_wallet_for_new_user(sender, instance, created, **kwargs):
    if created:
        Wallet.objects.create(user=instance)


@receiver(post_save, sender=Payment)
def sync_order_payment_status(sender, instance, **kwargs):
    from apps.orders.models import Order, OrderPaymentStatus

    status_map = {
        PaymentGatewayStatus.CAPTURED: OrderPaymentStatus.PAID,
        PaymentGatewayStatus.FAILED: OrderPaymentStatus.FAILED,
        PaymentGatewayStatus.REFUNDED: OrderPaymentStatus.REFUNDED,
    }
    new_order_payment_status = status_map.get(instance.status)
    if new_order_payment_status is None:
        return

    Order.objects.filter(pk=instance.order_id).exclude(payment_status=new_order_payment_status).update(
        payment_status=new_order_payment_status
    )
