from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.menu.services import calculate_price

pytestmark = pytest.mark.django_db


def test_pricing_with_no_discount(make_food):
    food = make_food(base_price=Decimal("100.00"), gst_rate=Decimal("5.00"))

    pricing = calculate_price(food)

    assert pricing["unit_price"] == Decimal("100.00")
    assert pricing["discount_amount"] == Decimal("0.00")
    assert pricing["gst_amount"] == Decimal("5.00")
    assert pricing["final_price"] == Decimal("105.00")


def test_pricing_with_percentage_discount(make_food):
    from apps.menu.models import FoodDiscount

    food = make_food(base_price=Decimal("200.00"), gst_rate=Decimal("18.00"))
    now = timezone.now()
    FoodDiscount.objects.create(
        food=food, discount_type="percentage", value=Decimal("10.00"),
        valid_from=now - timedelta(hours=1), valid_until=now + timedelta(hours=1),
    )

    pricing = calculate_price(food)

    assert pricing["discount_amount"] == Decimal("20.00")
    assert pricing["price_after_discount"] == Decimal("180.00")
    assert pricing["gst_amount"] == Decimal("32.40")
    assert pricing["final_price"] == Decimal("212.40")


def test_percentage_discount_capped_by_max_discount_amount(make_food):
    from apps.menu.models import FoodDiscount

    food = make_food(base_price=Decimal("1000.00"), gst_rate=Decimal("5.00"))
    now = timezone.now()
    FoodDiscount.objects.create(
        food=food, discount_type="percentage", value=Decimal("50.00"), max_discount_amount=Decimal("100.00"),
        valid_from=now - timedelta(hours=1), valid_until=now + timedelta(hours=1),
    )

    pricing = calculate_price(food)

    assert pricing["discount_amount"] == Decimal("100.00")
    assert pricing["price_after_discount"] == Decimal("900.00")


def test_flat_discount_cannot_exceed_unit_price(make_food):
    from apps.menu.models import FoodDiscount

    food = make_food(base_price=Decimal("50.00"), gst_rate=Decimal("0.00"))
    now = timezone.now()
    FoodDiscount.objects.create(
        food=food, discount_type="flat", value=Decimal("999.00"),
        valid_from=now - timedelta(hours=1), valid_until=now + timedelta(hours=1),
    )

    pricing = calculate_price(food)

    assert pricing["discount_amount"] == Decimal("50.00")
    assert pricing["price_after_discount"] == Decimal("0.00")
    assert pricing["final_price"] == Decimal("0.00")


def test_expired_discount_not_applied(make_food):
    from apps.menu.models import FoodDiscount

    food = make_food(base_price=Decimal("100.00"), gst_rate=Decimal("5.00"))
    now = timezone.now()
    FoodDiscount.objects.create(
        food=food, discount_type="flat", value=Decimal("20.00"),
        valid_from=now - timedelta(days=2), valid_until=now - timedelta(days=1),
    )

    pricing = calculate_price(food)

    assert pricing["discount_amount"] == Decimal("0.00")


def test_pricing_uses_variant_price_when_given(make_food):
    from apps.menu.models import FoodVariant

    food = make_food(base_price=Decimal("100.00"), gst_rate=Decimal("5.00"))
    variant = FoodVariant.objects.create(food=food, name="Full", price=Decimal("180.00"))

    pricing = calculate_price(food, variant=variant)

    assert pricing["unit_price"] == Decimal("180.00")
    assert pricing["gst_amount"] == Decimal("9.00")
    assert pricing["final_price"] == Decimal("189.00")


def test_invalid_gst_rate_rejected_at_model_level(make_food):
    from django.core.exceptions import ValidationError

    food = make_food(gst_rate=Decimal("13.00"))
    with pytest.raises(ValidationError):
        food.full_clean()
