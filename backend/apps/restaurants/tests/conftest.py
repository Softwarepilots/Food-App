from decimal import Decimal

import pytest


@pytest.fixture
def owner_user(make_user):
    from apps.accounts.models import UserRole

    return make_user(email="owner@test.com", phone_number="+919876500010", role=UserRole.RESTAURANT_OWNER)


@pytest.fixture
def other_owner_user(make_user):
    from apps.accounts.models import UserRole

    return make_user(email="owner2@test.com", phone_number="+919876500011", role=UserRole.RESTAURANT_OWNER)


@pytest.fixture
def admin_user(make_user):
    from apps.accounts.models import UserRole

    return make_user(email="admin@test.com", phone_number="+919876500012", role=UserRole.ADMIN)


@pytest.fixture
def customer_user(make_user):
    return make_user(email="customer@test.com", phone_number="+919876500013")


@pytest.fixture
def make_restaurant(owner_user):
    def _make_restaurant(owner=None, approval_status="approved", is_active=True, **extra):
        from apps.restaurants.models import Restaurant

        defaults = dict(
            owner=owner or owner_user,
            name="Test Restaurant",
            address_line="123 Test St",
            city="Chennai",
            latitude=Decimal("13.0827"),
            longitude=Decimal("80.2707"),
            approval_status=approval_status,
            is_active=is_active,
        )
        defaults.update(extra)
        restaurant = Restaurant.objects.create(**defaults)
        if approval_status == "approved":
            from apps.restaurants.models import DayOfWeek

            for day in DayOfWeek.values:
                restaurant.business_hours.create(day_of_week=day, opening_time="00:00", closing_time="23:59")
        return restaurant

    return _make_restaurant
