from decimal import Decimal

import pytest


@pytest.fixture
def owner_user(make_user):
    from apps.accounts.models import UserRole

    return make_user(email="orders-owner@test.com", phone_number="+919876520010", role=UserRole.RESTAURANT_OWNER)


@pytest.fixture
def customer_user(make_user):
    return make_user(email="orders-customer@test.com", phone_number="+919876520011")


@pytest.fixture
def make_restaurant(owner_user):
    def _make_restaurant(owner=None, **extra):
        from apps.restaurants.models import Restaurant

        defaults = dict(
            owner=owner or owner_user,
            name="Orders Test Restaurant",
            address_line="123 Test St",
            city="Chennai",
            latitude=Decimal("13.0827"),
            longitude=Decimal("80.2707"),
            approval_status="approved",
            is_active=True,
        )
        defaults.update(extra)
        restaurant = Restaurant.objects.create(**defaults)
        from apps.restaurants.models import DayOfWeek

        for day in DayOfWeek.values:
            restaurant.business_hours.create(day_of_week=day, opening_time="00:00", closing_time="23:59")
        return restaurant

    return _make_restaurant


@pytest.fixture
def make_food(make_restaurant):
    def _make_food(restaurant=None, **extra):
        from apps.menu.models import Food

        defaults = dict(
            restaurant=restaurant or make_restaurant(),
            name="Test Food",
            base_price=Decimal("100.00"),
        )
        defaults.update(extra)
        return Food.objects.create(**defaults)

    return _make_food


@pytest.fixture
def make_address(customer_user):
    def _make_address(user=None, **extra):
        from apps.accounts.models import Address

        defaults = dict(
            user=user or customer_user,
            address_line1="1 Test St",
            city="Chennai",
            state="Tamil Nadu",
            pincode="600001",
            latitude=Decimal("13.0827"),
            longitude=Decimal("80.2707"),
        )
        defaults.update(extra)
        return Address.objects.create(**defaults)

    return _make_address


@pytest.fixture
def make_order(customer_user, make_restaurant):
    def _make_order(restaurant=None, **extra):
        from apps.orders.models import Order

        defaults = dict(
            user=customer_user,
            restaurant=restaurant or make_restaurant(),
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
