import pytest

from apps.notifications.models import Notification, NotificationType
from apps.notifications.services import create_notification

pytestmark = pytest.mark.django_db


def test_create_notification_without_order(make_user):
    user = make_user()

    notification = create_notification(
        user_id=user.id,
        notification_type=NotificationType.SYSTEM,
        title="Welcome",
        body="Thanks for joining.",
    )

    assert Notification.objects.filter(pk=notification.pk).exists()
    assert notification.user_id == user.id
    assert notification.order_id is None
    assert notification.is_read is False


def test_create_notification_with_order(make_user):
    from decimal import Decimal

    from apps.accounts.models import UserRole
    from apps.orders.models import Order
    from apps.restaurants.models import Restaurant

    customer = make_user(email="notif-customer@test.com", phone_number="+919876550010")
    owner = make_user(email="notif-owner@test.com", phone_number="+919876550011", role=UserRole.RESTAURANT_OWNER)
    restaurant = Restaurant.objects.create(
        owner=owner,
        name="Notifications Test Restaurant",
        address_line="123 Test St",
        city="Chennai",
        latitude=Decimal("13.0827"),
        longitude=Decimal("80.2707"),
        approval_status="approved",
        is_active=True,
    )
    order = Order.objects.create(
        user=customer,
        restaurant=restaurant,
        delivery_address_text="1 Test St, Chennai",
        delivery_latitude=Decimal("13.0827"),
        delivery_longitude=Decimal("80.2707"),
        subtotal=Decimal("100.00"),
        delivery_fee=Decimal("30.00"),
        total_amount=Decimal("130.00"),
    )

    notification = create_notification(
        user_id=customer.id,
        notification_type=NotificationType.ORDER_UPDATE,
        title=f"Order {order.order_number}",
        body="Your order has been placed.",
        order_id=order.id,
    )

    assert notification.order_id == order.id
