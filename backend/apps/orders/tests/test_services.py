import pytest

from apps.orders.models import OrderPaymentStatus, OrderStatus
from apps.orders.services import (
    assign_delivery_partner,
    place_order,
    set_payment_status,
    update_order_status,
)

pytestmark = pytest.mark.django_db


def _make_delivery_partner(make_user, suffix="1"):
    from apps.accounts.models import UserRole
    from apps.delivery.models import DeliveryPartner, VehicleType

    user = make_user(
        email=f"orders-partner{suffix}@test.com",
        phone_number=f"+91987652009{suffix}",
        role=UserRole.DELIVERY_PARTNER,
    )
    return DeliveryPartner.objects.create(
        user=user,
        vehicle_type=VehicleType.BICYCLE,
        vehicle_number="TN01AB1234",
        license_number="DL1234567890",
        is_verified=True,
    )


def test_place_order_creates_payment_via_payments_service(customer_user, make_restaurant, make_food, make_address):
    from apps.payments.models import Payment, PaymentMethod

    restaurant = make_restaurant()
    food = make_food(restaurant=restaurant)
    address = make_address()

    order = place_order(
        customer_user,
        restaurant_id=restaurant.id,
        address_id=address.id,
        items_payload=[{"food_id": food.id, "quantity": 1}],
        payment_method="cod",
    )

    payment = Payment.objects.get(order=order)
    assert payment.method == PaymentMethod.COD
    assert payment.amount == order.total_amount


def test_update_order_status_reaches_delivered_from_out_for_delivery(make_order):
    order = make_order(status=OrderStatus.OUT_FOR_DELIVERY)

    updated = update_order_status(order, OrderStatus.DELIVERED)

    assert updated.status == OrderStatus.DELIVERED
    assert updated.delivered_at is not None


def test_assign_delivery_partner_claims_ready_order(make_order, make_user):
    partner = _make_delivery_partner(make_user)
    order = make_order(status=OrderStatus.READY_FOR_PICKUP)

    updated = assign_delivery_partner(order, partner)

    assert updated.status == OrderStatus.OUT_FOR_DELIVERY
    assert updated.delivery_partner_id == partner.id


def test_assign_delivery_partner_rejects_already_claimed_order(make_order, make_user):
    partner = _make_delivery_partner(make_user, suffix="1")
    other_partner = _make_delivery_partner(make_user, suffix="2")
    order = make_order(status=OrderStatus.OUT_FOR_DELIVERY, delivery_partner=partner)

    from apps.common.exceptions import ApplicationError

    with pytest.raises(ApplicationError):
        assign_delivery_partner(order, other_partner)


def test_set_payment_status_updates_order_without_touching_other_fields(make_order):
    order = make_order(payment_status=OrderPaymentStatus.PENDING)

    set_payment_status(order.id, OrderPaymentStatus.PAID)

    order.refresh_from_db()
    assert order.payment_status == OrderPaymentStatus.PAID
