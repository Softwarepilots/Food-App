import pytest

pytestmark = pytest.mark.django_db


def _list_url(restaurant_id):
    return f"/api/v1/menu/restaurants/{restaurant_id}/categories/"


def _detail_url(restaurant_id, pk):
    return f"/api/v1/menu/restaurants/{restaurant_id}/categories/{pk}/"


def test_owner_can_create_category(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)

    response = api_client.post(
        _list_url(restaurant.id), {"name": "Starters"}, format="json", HTTP_AUTHORIZATION=auth_header(owner_user)
    )

    assert response.status_code == 201
    assert response.json()["data"]["name"] == "Starters"


def test_other_owner_cannot_create_category(api_client, make_restaurant, other_owner_user, auth_header):
    restaurant = make_restaurant()

    response = api_client.post(
        _list_url(restaurant.id), {"name": "Starters"}, format="json", HTTP_AUTHORIZATION=auth_header(other_owner_user)
    )

    assert response.status_code == 403


def test_public_can_list_categories(api_client, make_restaurant):
    from apps.menu.models import FoodCategory

    restaurant = make_restaurant()
    FoodCategory.objects.create(restaurant=restaurant, name="Mains")

    response = api_client.get(_list_url(restaurant.id))

    assert response.status_code == 200
    assert len(response.json()["data"]) == 1


def test_duplicate_category_name_rejected(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    header = auth_header(owner_user)
    api_client.post(_list_url(restaurant.id), {"name": "Starters"}, format="json", HTTP_AUTHORIZATION=header)

    response = api_client.post(_list_url(restaurant.id), {"name": "Starters"}, format="json", HTTP_AUTHORIZATION=header)

    assert response.status_code == 400


def test_owner_can_update_and_delete_category(api_client, make_restaurant, owner_user, auth_header):
    restaurant = make_restaurant(owner=owner_user)
    header = auth_header(owner_user)
    category = api_client.post(
        _list_url(restaurant.id), {"name": "Starters"}, format="json", HTTP_AUTHORIZATION=header
    ).json()["data"]

    update_response = api_client.patch(
        _detail_url(restaurant.id, category["id"]), {"sort_order": 5}, format="json", HTTP_AUTHORIZATION=header
    )
    delete_response = api_client.delete(_detail_url(restaurant.id, category["id"]), HTTP_AUTHORIZATION=header)

    assert update_response.status_code == 200
    assert update_response.json()["data"]["sort_order"] == 5
    assert delete_response.status_code == 204
