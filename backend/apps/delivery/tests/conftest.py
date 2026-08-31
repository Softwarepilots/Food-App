from decimal import Decimal

import pytest


@pytest.fixture
def owner_user(make_user):
    from apps.accounts.models import UserRole

    return make_user(email="delivery-owner@test.com", phone_number="+919876530010", role=UserRole.RESTAURANT_OWNER)


@pytest.fixture
def customer_user(make_user):
    return make_user(email="delivery-customer@test.com", phone_number="+919876530011")


@pytest.fixture
def make_partner(make_user):
    def _make_partner(suffix="1", **extra):
        from apps.accounts.models import UserRole
        from apps.delivery.models import DeliveryPartner, VehicleType

        user = make_user(
            email=f"delivery-partner{suffix}@test.com",
            phone_number=f"+91987653002{suffix}",
            role=UserRole.DELIVERY_PARTNER,
        )
        defaults = dict(
            user=user,
            vehicle_type=VehicleType.BICYCLE,
            vehicle_number="TN01AB1234",
            license_number="DL1234567890",
            is_verified=True,
        )
        defaults.update(extra)
        return DeliveryPartner.objects.create(**defaults)

    return _make_partner


@pytest.fixture
def make_restaurant(owner_user):
    def _make_restaurant(owner=None, **extra):
        from apps.restaurants.models import Restaurant

        defaults = dict(
            owner=owner or owner_user,
            name="Delivery Test Restaurant",
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
