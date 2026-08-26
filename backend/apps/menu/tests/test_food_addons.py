import pytest

pytestmark = pytest.mark.django_db


def _list_url(food_id):
    return f"/api/v1/menu/foods/{food_id}/addons/"


def _detail_url(food_id, pk):
    return f"/api/v1/menu/foods/{food_id}/addons/{pk}/"


def test_owner_can_create_addon(api_client, make_food, owner_user, auth_header):
    food = make_food()

    response = api_client.post(
        _list_url(food.id), {"name": "Extra Cheese", "price": "20.00"}, format="json", HTTP_AUTHORIZATION=auth_header(owner_user)
    )

    assert response.status_code == 201
    assert response.json()["data"]["name"] == "Extra Cheese"


def test_duplicate_addon_name_rejected(api_client, make_food, owner_user, auth_header):
    food = make_food()
    header = auth_header(owner_user)
    api_client.post(_list_url(food.id), {"name": "Extra Cheese", "price": "20.00"}, format="json", HTTP_AUTHORIZATION=header)

    response = api_client.post(_list_url(food.id), {"name": "Extra Cheese", "price": "25.00"}, format="json", HTTP_AUTHORIZATION=header)

    assert response.status_code == 400


def test_owner_can_update_and_delete_addon(api_client, make_food, owner_user, auth_header):
    food = make_food()
    header = auth_header(owner_user)
    addon = api_client.post(
        _list_url(food.id), {"name": "Extra Cheese", "price": "20.00"}, format="json", HTTP_AUTHORIZATION=header
    ).json()["data"]

    update_response = api_client.patch(
        _detail_url(food.id, addon["id"]), {"is_available": False}, format="json", HTTP_AUTHORIZATION=header
    )
    delete_response = api_client.delete(_detail_url(food.id, addon["id"]), HTTP_AUTHORIZATION=header)

    assert update_response.status_code == 200
    assert update_response.json()["data"]["is_available"] is False
    assert delete_response.status_code == 204
