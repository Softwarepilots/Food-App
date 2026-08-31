import pytest

from apps.common.exceptions import ApplicationError
from apps.delivery.models import DeliveryPartnerStatus
from apps.delivery.services import accept_order, mark_delivered
from apps.orders.models import OrderStatus

pytestmark = pytest.mark.django_db


def test_accept_order_assigns_partner_and_flips_order_status(make_order, make_partner):
    partner = make_partner(status=DeliveryPartnerStatus.ONLINE)
    order = make_order(status=OrderStatus.READY_FOR_PICKUP)

    updated = accept_order(order, partner)

    assert updated.status == OrderStatus.OUT_FOR_DELIVERY
    assert updated.delivery_partner_id == partner.id
    partner.refresh_from_db()
    assert partner.status == DeliveryPartnerStatus.ON_DELIVERY


def test_accept_order_rejects_unverified_partner(make_order, make_partner):
    partner = make_partner(status=DeliveryPartnerStatus.ONLINE, is_verified=False)
    order = make_order(status=OrderStatus.READY_FOR_PICKUP)

    with pytest.raises(ApplicationError):
        accept_order(order, partner)


def test_accept_order_rejects_already_claimed_order(make_order, make_partner):
    partner = make_partner(suffix="1", status=DeliveryPartnerStatus.ONLINE)
    other_partner = make_partner(suffix="2", status=DeliveryPartnerStatus.ONLINE)
    order = make_order(status=OrderStatus.OUT_FOR_DELIVERY, delivery_partner=partner)

    with pytest.raises(ApplicationError):
        accept_order(order, other_partner)


def test_mark_delivered_completes_order_and_frees_partner(make_order, make_partner):
    partner = make_partner(status=DeliveryPartnerStatus.ON_DELIVERY)
    order = make_order(status=OrderStatus.OUT_FOR_DELIVERY, delivery_partner=partner)

    updated = mark_delivered(order, partner)

    assert updated.status == OrderStatus.DELIVERED
    assert updated.delivered_at is not None
    partner.refresh_from_db()
    assert partner.status == DeliveryPartnerStatus.ONLINE


def test_mark_delivered_increments_partner_total_deliveries(make_order, make_partner):
    """Regression check: apps.delivery.signals.increment_delivery_partner_stats
    must still fire now that mark_delivered goes through
    apps.orders.services.update_order_status instead of a direct order.save()."""
    partner = make_partner(status=DeliveryPartnerStatus.ON_DELIVERY, total_deliveries=0)
    order = make_order(status=OrderStatus.OUT_FOR_DELIVERY, delivery_partner=partner)

    mark_delivered(order, partner)

    partner.refresh_from_db()
    assert partner.total_deliveries == 1


def test_mark_delivered_rejects_wrong_partner(make_order, make_partner):
    partner = make_partner(suffix="1", status=DeliveryPartnerStatus.ON_DELIVERY)
    other_partner = make_partner(suffix="2", status=DeliveryPartnerStatus.ON_DELIVERY)
    order = make_order(status=OrderStatus.OUT_FOR_DELIVERY, delivery_partner=partner)

    with pytest.raises(ApplicationError):
        mark_delivered(order, other_partner)
