from datetime import timedelta

import pytest
from django.utils import timezone

pytestmark = pytest.mark.django_db


def _list_url(food_id):
    return f"/api/v1/menu/foods/{food_id}/discounts/"


def _detail_url(food_id, pk):
    return f"/api/v1/menu/foods/{food_id}/discounts/{pk}/"


def _window():
    now = timezone.now()
    return (now - timedelta(hours=1)).isoformat(), (now + timedelta(days=1)).isoformat()


def test_owner_can_create_discount(api_client, make_food, owner_user, auth_header):
    food = make_food()
    valid_from, valid_until = _window()

    response = api_client.post(
        _list_url(food.id),
        {"discount_type": "percentage", "value": "10.00", "valid_from": valid_from, "valid_until": valid_until},
        format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 201
    assert response.json()["data"]["discount_type"] == "percentage"


def test_percentage_discount_over_100_rejected(api_client, make_food, owner_user, auth_header):
    food = make_food()
    valid_from, valid_until = _window()

    response = api_client.post(
        _list_url(food.id),
        {"discount_type": "percentage", "value": "150.00", "valid_from": valid_from, "valid_until": valid_until},
        format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 400


def test_valid_until_before_valid_from_rejected(api_client, make_food, owner_user, auth_header):
    food = make_food()
    now = timezone.now()

    response = api_client.post(
        _list_url(food.id),
        {
            "discount_type": "flat", "value": "10.00",
            "valid_from": now.isoformat(), "valid_until": (now - timedelta(hours=1)).isoformat(),
        },
        format="json",
        HTTP_AUTHORIZATION=auth_header(owner_user),
    )

    assert response.status_code == 400


def test_other_owner_cannot_create_discount(api_client, make_food, other_owner_user, auth_header):
    food = make_food()
    valid_from, valid_until = _window()

    response = api_client.post(
        _list_url(food.id),
        {"discount_type": "flat", "value": "10.00", "valid_from": valid_from, "valid_until": valid_until},
        format="json",
        HTTP_AUTHORIZATION=auth_header(other_owner_user),
    )

    assert response.status_code == 403


def test_public_can_list_discounts(api_client, make_food):
    from apps.menu.models import FoodDiscount

    food = make_food()
    valid_from, valid_until = _window()
    FoodDiscount.objects.create(
        food=food, discount_type="flat", value="15.00", valid_from=valid_from, valid_until=valid_until
    )

    response = api_client.get(_list_url(food.id))

    assert response.status_code == 200
    assert len(response.json()["data"]) == 1
