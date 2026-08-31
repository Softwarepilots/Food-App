from decimal import Decimal

import pytest


@pytest.fixture
def owner_user(make_user):
    from apps.accounts.models import UserRole

    return make_user(email="payments-owner@test.com", phone_number="+919876540010", role=UserRole.RESTAURANT_OWNER)


@pytest.fixture
def customer_user(make_user):
    return make_user(email="payments-customer@test.com", phone_number="+919876540011")


@pytest.fixture
def make_order(customer_user, owner_user):
    def _make_order(**extra):
        from apps.orders.models import Order
        from apps.restaurants.models import Restaurant

        restaurant = Restaurant.objects.create(
            owner=owner_user,
            name="Payments Test Restaurant",
            address_line="123 Test St",
            city="Chennai",
            latitude=Decimal("13.0827"),
            longitude=Decimal("80.2707"),
            approval_status="approved",
            is_active=True,
        )
        defaults = dict(
            user=customer_user,
            restaurant=restaurant,
            delivery_address_text="1 Test St, Chennai",
            delivery_latitude=Decimal("13.0827"),
            delivery_longitude=Decimal("80.2707"),
            subtotal=Decimal("100.00"),
            delivery_fee=Decimal("30.00"),
            total_amount=Decimal("130.00"),
        )
        defaults.update(extra)
        return Order.objects.create(**defaults)

    return _make_order
