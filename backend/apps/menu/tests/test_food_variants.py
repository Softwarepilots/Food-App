import pytest

pytestmark = pytest.mark.django_db


def _list_url(food_id):
    return f"/api/v1/menu/foods/{food_id}/variants/"


def _detail_url(food_id, pk):
    return f"/api/v1/menu/foods/{food_id}/variants/{pk}/"


def _inventory_url(food_id, pk):
    return f"/api/v1/menu/foods/{food_id}/variants/{pk}/inventory/"


def test_owner_can_create_variant(api_client, make_food, owner_user, auth_header):
    food = make_food()

    response = api_client.post(
        _list_url(food.id), {"name": "Full", "price": "250.00"}, format="json", HTTP_AUTHORIZATION=auth_header(owner_user)
    )

    assert response.status_code == 201
    assert response.json()["data"]["name"] == "Full"


def test_other_owner_cannot_create_variant(api_client, make_food, other_owner_user, auth_header):
    food = make_food()

    response = api_client.post(
        _list_url(food.id), {"name": "Full", "price": "250.00"}, format="json", HTTP_AUTHORIZATION=auth_header(other_owner_user)
    )

    assert response.status_code == 403


def test_second_default_variant_demotes_first(api_client, make_food, owner_user, auth_header):
    food = make_food()
    header = auth_header(owner_user)
    first = api_client.post(
        _list_url(food.id), {"name": "Half", "price": "120.00", "is_default": True}, format="json", HTTP_AUTHORIZATION=header
    ).json()["data"]

    api_client.post(
        _list_url(food.id), {"name": "Full", "price": "220.00", "is_default": True}, format="json", HTTP_AUTHORIZATION=header
    )

    response = api_client.get(_list_url(food.id), HTTP_AUTHORIZATION=header)
    first_variant = next(v for v in response.json()["data"] if v["id"] == first["id"])
    assert first_variant["is_default"] is False


def test_variant_inventory_update(api_client, make_food, owner_user, auth_header):
    food = make_food()
    header = auth_header(owner_user)
    variant = api_client.post(
        _list_url(food.id), {"name": "Full", "price": "250.00"}, format="json", HTTP_AUTHORIZATION=header
    ).json()["data"]

    response = api_client.patch(
        _inventory_url(food.id, variant["id"]),
        {"track_inventory": True, "stock_quantity": 10, "low_stock_threshold": 3},
        format="json",
        HTTP_AUTHORIZATION=header,
    )

    assert response.status_code == 200
    assert response.json()["data"]["stock_quantity"] == 10
    assert response.json()["data"]["is_in_stock"] is True


def test_owner_can_delete_variant(api_client, make_food, owner_user, auth_header):
    food = make_food()
    header = auth_header(owner_user)
    variant = api_client.post(
        _list_url(food.id), {"name": "Full", "price": "250.00"}, format="json", HTTP_AUTHORIZATION=header
    ).json()["data"]

    response = api_client.delete(_detail_url(food.id, variant["id"]), HTTP_AUTHORIZATION=header)

    assert response.status_code == 204
