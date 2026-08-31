from django.db import transaction

from apps.common.exceptions import ApplicationError
from apps.orders import services as orders_services
from apps.orders.models import Order, OrderStatus

from .models import DeliveryPartnerStatus


@transaction.atomic
def accept_order(order, partner):
    if not partner.is_verified:
        raise ApplicationError("Your account is pending verification.", code="not_verified", status_code=403)
    if partner.status != DeliveryPartnerStatus.ONLINE:
        raise ApplicationError("Go online to accept deliveries.", code="not_online", status_code=400)

    orders_services.assign_delivery_partner(order, partner)

    partner.status = DeliveryPartnerStatus.ON_DELIVERY
    partner.save(update_fields=["status"])
    return order


@transaction.atomic
def mark_delivered(order, partner):
    if order.delivery_partner_id != partner.id:
        raise ApplicationError("This order is not assigned to you.", code="not_your_delivery", status_code=403)
    if order.status != OrderStatus.OUT_FOR_DELIVERY:
        raise ApplicationError(
            f'Cannot mark an order "{order.status}" as delivered.', code="invalid_transition", status_code=400
        )

    # Also fires apps.delivery.signals.increment_delivery_partner_stats,
    # which atomically bumps partner.total_deliveries — don't also do it here.
    orders_services.update_order_status(order, OrderStatus.DELIVERED)

    partner.status = DeliveryPartnerStatus.ONLINE
    partner.save(update_fields=["status"])
    return order


def set_status(partner, new_status):
    partner.status = new_status
    partner.save(update_fields=["status"])
    return partner


def available_orders_queryset():
    return Order.objects.filter(status=OrderStatus.READY_FOR_PICKUP, delivery_partner__isnull=True)
