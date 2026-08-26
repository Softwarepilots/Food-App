from decimal import Decimal

import pytest


@pytest.fixture
def owner_user(make_user):
    from apps.accounts.models import UserRole

    return make_user(email="menu-owner@test.com", phone_number="+919876510010", role=UserRole.RESTAURANT_OWNER)


@pytest.fixture
def other_owner_user(make_user):
    from apps.accounts.models import UserRole

    return make_user(email="menu-owner2@test.com", phone_number="+919876510011", role=UserRole.RESTAURANT_OWNER)


@pytest.fixture
def admin_user(make_user):
    from apps.accounts.models import UserRole

    return make_user(email="menu-admin@test.com", phone_number="+919876510012", role=UserRole.ADMIN)


@pytest.fixture
def customer_user(make_user):
    return make_user(email="menu-customer@test.com", phone_number="+919876510013")


@pytest.fixture
def make_restaurant(owner_user):
    def _make_restaurant(owner=None, **extra):
        from apps.restaurants.models import Restaurant

        defaults = dict(
            owner=owner or owner_user,
            name="Menu Test Restaurant",
            address_line="123 Test St",
            city="Chennai",
            latitude=Decimal("13.0827"),
            longitude=Decimal("80.2707"),
            approval_status="approved",
            is_active=True,
        )
        defaults.update(extra)
        return Restaurant.objects.create(**defaults)

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
